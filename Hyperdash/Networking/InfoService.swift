import Foundation

/// Read-model for a wallet screen. The only code that knows how `allMids` is
/// keyed: perp marks live under the coin name, spot mids under "@<pair index>".
/// Every USD valuation question is answered here; views render, never price.
struct WalletSnapshot {
    let perps: PerpsState
    let spot: SpotState
    let openOrders: [OpenOrder]
    private let mids: [String: Double]
    private let spotMidKeys: [String: String]

    init(perps: PerpsState, spot: SpotState, openOrders: [OpenOrder],
         mids: [String: Double], spotMidKeys: [String: String]) {
        self.perps = perps
        self.spot = spot
        self.openOrders = openOrders
        self.mids = mids
        self.spotMidKeys = spotMidKeys
    }

    var totalAccountValue: Double {
        perps.accountValue + spotUSDValue
    }

    var spotUSDValue: Double {
        spot.nonZeroBalances.reduce(0) { $0 + (usdValue(of: $1) ?? 0) }
    }

    /// USDC held in the spot wallet (already dollar-denominated).
    var spotUSDC: Double {
        spot.balances.first(where: \.isUSDC)?.totalValue ?? 0
    }

    /// "Balance (USDC)" as shown on the copy-trade dashboard. Perp equity and spot
    /// USDC often track the same funds, so within 10% they're treated as one balance
    /// rather than summed, matching the reference `computeAccountValue` heuristic.
    var accountBalanceUSDC: Double {
        let perp = perps.accountValue
        let spotUsdc = spotUSDC
        guard spotUsdc > 0 else { return perp }
        let larger = max(perp, spotUsdc)
        let smaller = min(perp, spotUsdc)
        if smaller / larger >= 0.9 { return larger }
        return perp < spotUsdc ? spotUsdc : perp + spotUsdc
    }

    /// Sum of unrealized PnL across all open perp positions.
    var totalUnrealizedPnl: Double {
        perps.openPositions.reduce(0) { $0 + $1.unrealizedPnlValue }
    }

    /// Open-position notional exposure split by side, for the short/long ratio bar.
    var sideExposure: SideExposure {
        var long = SideExposure.Side()
        var short = SideExposure.Side()
        for position in perps.openPositions {
            if position.isLong {
                long.notional += position.notionalValue
                long.count += 1
            } else {
                short.notional += position.notionalValue
                short.count += 1
            }
        }
        return SideExposure(long: long, short: short)
    }

    /// Mark price for a perp coin.
    func mark(for coin: String) -> Double? { mids[coin] }

    /// USD value of a spot balance, or nil when no current price is known.
    func usdValue(of balance: SpotBalance) -> Double? {
        if balance.isUSDC { return balance.totalValue }
        guard let key = spotMidKeys[balance.coin], let mid = mids[key], mid > 0 else {
            return nil
        }
        return balance.totalValue * mid
    }
}

struct SideExposure {
    struct Side {
        var notional: Double = 0
        var count: Int = 0
    }

    let long: Side
    let short: Side

    var total: Double { long.notional + short.notional }
    var longShare: Double? { total > 0 ? long.notional / total : nil }
    var shortShare: Double? { total > 0 ? short.notional / total : nil }

    /// Short-to-long exposure ratio, matching the reference dashboard's "short / long".
    var ratio: Double? { long.notional > 0 ? short.notional / long.notional : nil }
}

struct InfoService {
    let client: HyperliquidClient
    let meta: MetaService

    func allMids() async throws -> [String: Double] {
        let raw = try await client.info(["type": "allMids"], as: [String: String].self)
        return raw.mapValues { $0.hlDouble }
    }

    func snapshot(address: String) async throws -> WalletSnapshot {
        async let perps = client.info(["type": "clearinghouseState", "user": address], as: PerpsState.self)
        async let spot = client.info(["type": "spotClearinghouseState", "user": address], as: SpotState.self)
        async let orders = client.info(["type": "frontendOpenOrders", "user": address], as: [OpenOrder].self)
        async let mids = allMids()

        let spotState = try await spot
        var spotMidKeys: [String: String] = [:]
        for balance in spotState.nonZeroBalances where !balance.isUSDC {
            if let key = try? await meta.spotMidKey(coin: balance.coin) {
                spotMidKeys[balance.coin] = key
            }
        }

        return try await WalletSnapshot(
            perps: perps, spot: spotState, openOrders: orders,
            mids: mids, spotMidKeys: spotMidKeys
        )
    }
}
