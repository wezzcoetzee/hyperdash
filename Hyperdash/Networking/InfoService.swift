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
