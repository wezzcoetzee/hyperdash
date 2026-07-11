import Foundation

/// Pure alert logic: given current marks, open positions, and configuration,
/// decide which notifications to fire and return the updated alert state.
///
/// This is the "push-ready" seam — it has no dependency on the network, the
/// background task, or notification delivery. The on-device background runner
/// and any future server-side polling worker feed it the same inputs.
enum AlertEvaluator {
    /// A position must recover this many points past the threshold before a
    /// cleared liquidation alert can fire again (hysteresis against flapping).
    static let liquidationRearmMarginPct = 2.0

    struct Position: Equatable {
        let walletName: String
        let coin: String
        let liquidationPrice: Double?
        let isLong: Bool
    }

    struct Event: Equatable {
        let id: String
        let title: String
        let body: String
    }

    struct Input {
        var marks: [String: Double]
        var positions: [Position]
        var config: AlertConfig
        /// Keys ("wallet|coin") of positions already alerted, to suppress repeats.
        var firedLiquidations: Set<String>
        var now: Date = Date()
    }

    struct Output: Equatable {
        var events: [Event]
        var priceAlerts: [PriceAlert]
        var firedLiquidations: Set<String>
    }

    static func evaluate(_ input: Input) -> Output {
        var events: [Event] = []
        var fired = input.firedLiquidations
        var alerts = input.config.priceAlerts

        if input.config.liquidationEnabled {
            let threshold = input.config.liquidationThresholdPct
            for pos in input.positions {
                guard let liq = pos.liquidationPrice, liq > 0,
                      let mark = input.marks[pos.coin], mark > 0 else { continue }
                let distPct = abs(mark - liq) / mark * 100
                let key = "\(pos.walletName)|\(pos.coin)"
                if distPct <= threshold {
                    if !fired.contains(key) {
                        fired.insert(key)
                        events.append(Event(
                            id: "liq-\(key)",
                            title: "Liquidation risk",
                            body: "\(pos.coin) \(pos.isLong ? "LONG" : "SHORT") on \(pos.walletName) is "
                                + "\(Format.number(distPct, fractionDigits: 1))% from liquidation "
                                + "(\(Format.price(liq)))."
                        ))
                    }
                } else if distPct > threshold + liquidationRearmMarginPct {
                    fired.remove(key)
                }
            }
            // Drop fired entries for positions that are gone (closed), so a
            // reopened position can alert again.
            let liveKeys = Set(input.positions.map { "\($0.walletName)|\($0.coin)" })
            fired = fired.filter { liveKeys.contains($0) }
        }

        for i in alerts.indices {
            guard alerts[i].isPending,
                  let mark = input.marks[alerts[i].coin], mark > 0 else { continue }
            let target = alerts[i].target
            let onOppositeSide = alerts[i].direction == .above ? mark < target : mark > target
            if !alerts[i].isArmed {
                if onOppositeSide { alerts[i].isArmed = true }
                continue
            }
            let crossed = alerts[i].direction == .above ? mark >= target : mark <= target
            if crossed {
                alerts[i].triggeredAt = input.now
                events.append(Event(
                    id: "price-\(alerts[i].id.uuidString)",
                    title: "\(alerts[i].coin) price alert",
                    body: "\(alerts[i].coin) \(alerts[i].direction.crossedLabel) \(Format.price(mark)) "
                        + "(target \(Format.price(target)))."
                ))
            }
        }

        return Output(events: events, priceAlerts: alerts, firedLiquidations: fired)
    }
}
