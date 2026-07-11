import Foundation
import UserNotifications

/// Fetches current market state, runs the pure `AlertEvaluator`, persists the
/// updated alert state, and delivers local notifications for any fired events.
/// Invoked both in the foreground (while the app is open) and from the
/// background refresh task.
struct AlertRunner {
    let session: HyperliquidSession
    let wallets: [Wallet]
    var defaults: UserDefaults = .standard
    var notifier: NotificationDelivering = UNUserNotificationCenter.current()

    func run() async {
        let config = AlertPersistence.load(from: defaults)
        guard config.hasAny else { return }

        do {
            let marks = try await session.info.allMids()
            var positions: [AlertEvaluator.Position] = []
            if config.liquidationEnabled {
                for wallet in wallets {
                    guard let state = try? await session.info.perpsState(address: wallet.address) else { continue }
                    positions += state.openPositions.map {
                        AlertEvaluator.Position(
                            walletName: wallet.name,
                            coin: $0.coin,
                            liquidationPrice: $0.liquidationPrice,
                            isLong: $0.isLong
                        )
                    }
                }
            }

            let output = AlertEvaluator.evaluate(.init(
                marks: marks,
                positions: positions,
                config: config,
                firedLiquidations: AlertPersistence.loadFired(from: defaults)
            ))

            var updated = config
            updated.priceAlerts = output.priceAlerts
            AlertPersistence.save(updated, to: defaults)
            AlertPersistence.saveFired(output.firedLiquidations, to: defaults)

            for event in output.events {
                await notifier.deliver(id: event.id, title: event.title, body: event.body)
            }
        } catch {
            // Best-effort: a failed refresh just means we try again next wake.
        }
    }
}

/// Seam over notification delivery so the runner stays testable.
protocol NotificationDelivering {
    func deliver(id: String, title: String, body: String) async
}

extension UNUserNotificationCenter: NotificationDelivering {
    func deliver(id: String, title: String, body: String) async {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        let request = UNNotificationRequest(identifier: id, content: content, trigger: nil)
        try? await add(request)
    }
}
