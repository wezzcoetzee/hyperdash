import Foundation

/// An open perp position together with the DEX whose clearinghouse reported it.
/// `dex` is the empty string for the core Hyperliquid perp DEX and the builder's
/// name (e.g. "xyz") for a HIP-3 DEX — the same string those info requests take.
struct DexPosition: Identifiable {
    let dex: String
    let position: Position

    var id: String { "\(dex):\(position.coin)" }

    /// Core-DEX positions are the only ones the trade desk can act on: asset ids
    /// are DEX-scoped, and `MetaService` resolves them against the core `meta`.
    var isCore: Bool { dex.isEmpty }
}

/// Read-model for a wallet screen. The only code that knows how `allMids` is
/// keyed: perp marks live under the coin name, spot mids under "@<pair index>".
/// Mids are fetched per DEX and stored that way, because a coin name is only
/// unique within one DEX. Every USD valuation question is answered here; views
/// render, never price.
struct WalletSnapshot {
    let perps: PerpsState
    /// Clearinghouse state per builder-deployed DEX, keyed by DEX name. Only
    /// DEXs where this wallet actually holds a position are present.
    let builderPerps: [String: PerpsState]
    let spot: SpotState
    let openOrders: [OpenOrder]
    let abstraction: AccountAbstraction
    private let mids: [String: [String: Double]]
    private let spotMidKeys: [String: String]

    init(perps: PerpsState, builderPerps: [String: PerpsState] = [:],
         spot: SpotState, openOrders: [OpenOrder],
         abstraction: AccountAbstraction = .standard,
         mids: [String: [String: Double]], spotMidKeys: [String: String]) {
        self.perps = perps
        self.builderPerps = builderPerps
        self.spot = spot
        self.openOrders = openOrders
        self.abstraction = abstraction
        self.mids = mids
        self.spotMidKeys = spotMidKeys
    }

    /// Every open position the wallet holds, core DEX first, then builder DEXs
    /// in name order so the list doesn't reshuffle between refreshes.
    var openPositions: [DexPosition] {
        let core = perps.openPositions.map { DexPosition(dex: "", position: $0) }
        let builders = builderPerps.keys.sorted().flatMap { dex in
            builderPerps[dex]!.openPositions.map { DexPosition(dex: dex, position: $0) }
        }
        return core + builders
    }

    /// Under unified account and portfolio margin the spot clearinghouse already
    /// holds the perp collateral, so `spotUSDValue` is the whole account and
    /// adding perps equity would double-count it. Only a standard account keeps
    /// the two balances apart and sums them.
    var totalAccountValue: Double {
        valuesFromSpotAlone ? spotUSDValue : perpsAccountValue + spotUSDValue
    }

    /// Perp equity across every DEX. Only a standard account keeps a separate
    /// balance per clearinghouse, so only there do the builder DEXs' margin
    /// summaries add anything: under unified account and portfolio margin each
    /// one restates a slice of the one spot balance, and summing double-counts.
    var perpsAccountValue: Double {
        guard abstraction == .standard else { return perps.accountValue }
        return builderPerps.values.reduce(perps.accountValue) { $0 + $1.accountValue }
    }

    /// Margin committed to open positions across every DEX. Unlike account
    /// value this sums in every mode — it is the total of each position's own
    /// margin, not a restatement of the collateral backing them.
    var totalMarginUsed: Double {
        builderPerps.values.reduce(perps.totalMarginUsed) { $0 + $1.totalMarginUsed }
    }

    var maintenanceMarginUsed: Double {
        builderPerps.values.reduce(perps.maintenanceMarginUsed) { $0 + $1.maintenanceMarginUsed }
    }

    /// Whether this wallet's totals come from the spot side alone. A unified
    /// account whose spot side prices to nothing — an unreachable spot state, or
    /// holdings with no mid — would otherwise report a $0 account while the perp
    /// state plainly shows equity, so summing stays the fallback there.
    var valuesFromSpotAlone: Bool {
        abstraction.spotHoldsWholeAccount && spotUSDValue > 0
    }

    var spotUSDValue: Double {
        spot.nonZeroBalances.reduce(0) { $0 + (usdValue(of: $1) ?? 0) }
    }

    /// USDC held in the spot wallet (already dollar-denominated).
    var spotUSDC: Double {
        spot.balances.first(where: \.isUSDC)?.totalValue ?? 0
    }

    /// "Balance (USDC)" as shown on the copy-trade dashboard. A unified account
    /// needs no reconciling — its spot side already covers everything backing the
    /// positions. For a standard account, perp equity and spot USDC often track
    /// the same funds, so within 10% they're treated as one balance rather than
    /// summed, matching the reference `computeAccountValue` heuristic.
    var accountBalanceUSDC: Double {
        guard !valuesFromSpotAlone else { return spotUSDValue }
        let perp = perpsAccountValue
        let spotUsdc = spotUSDC
        guard spotUsdc > 0 else { return perp }
        let larger = max(perp, spotUsdc)
        let smaller = min(perp, spotUsdc)
        if smaller / larger >= 0.9 { return larger }
        return perp < spotUsdc ? spotUsdc : perp + spotUsdc
    }

    /// Gross open-position exposure divided by the same USDC balance shown on
    /// the wallet dashboard.
    var accountLeverage: Double {
        let balance = accountBalanceUSDC
        guard balance > 0 else { return 0 }
        return sideExposure.total / balance
    }

    /// Sum of unrealized PnL across all open perp positions, every DEX included.
    var totalUnrealizedPnl: Double {
        openPositions.reduce(0) { $0 + $1.position.unrealizedPnlValue }
    }

    /// Open-position notional exposure split by side, for the short/long ratio bar.
    var sideExposure: SideExposure {
        var long = SideExposure.Side()
        var short = SideExposure.Side()
        for position in openPositions.map(\.position) {
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

    /// Mark price for an open position, read from its own DEX's mids.
    func mark(for position: DexPosition) -> Double? {
        mids[position.dex]?[position.position.coin]
    }

    /// USD value of a spot balance, or nil when no current price is known.
    /// Spot mids are only served alongside the core DEX.
    func usdValue(of balance: SpotBalance) -> Double? {
        if balance.isUSDC { return balance.totalValue }
        guard let key = spotMidKeys[balance.coin], let mid = mids[""]?[key], mid > 0 else {
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

extension SideExposure {
    static func combined(_ exposures: [SideExposure]) -> SideExposure {
        var long = Side()
        var short = Side()
        for e in exposures {
            long.notional += e.long.notional;  long.count += e.long.count
            short.notional += e.short.notional; short.count += e.short.count
        }
        return SideExposure(long: long, short: short)
    }
}

struct ExtraAgent: Decodable, Equatable {
    let name: String
    let address: String
    let validUntil: Date

    enum CodingKeys: String, CodingKey { case name, address, validUntil }

    init(name: String, address: String, validUntil: Date) {
        self.name = name
        self.address = address
        self.validUntil = validUntil
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        name = try c.decode(String.self, forKey: .name)
        address = try c.decode(String.self, forKey: .address)
        let ms = try c.decode(Double.self, forKey: .validUntil)
        validUntil = Date(timeIntervalSince1970: ms / 1000)
    }
}

struct InfoService {
    let client: HyperliquidClient
    let meta: MetaService

    /// Mids for one perp DEX. The empty dex string is the core DEX, and is the
    /// only one whose response also carries spot mids.
    func allMids(dex: String = "") async throws -> [String: Double] {
        var body: [String: Any] = ["type": "allMids"]
        if !dex.isEmpty { body["dex"] = dex }
        let raw = try await client.info(body, as: [String: String].self)
        return raw.mapValues { $0.hlDouble }
    }

    /// Perps account state only — used by the alert runner, which needs open
    /// positions and liquidation prices but not the full spot/orders snapshot.
    func perpsState(address: String) async throws -> PerpsState {
        try await client.info(["type": "clearinghouseState", "user": address], as: PerpsState.self)
    }

    func portfolio(address: String) async throws -> PortfolioResponse {
        try await client.info(["type": "portfolio", "user": address], as: PortfolioResponse.self)
    }

    func extraAgents(address: String) async throws -> [ExtraAgent] {
        try await client.info(["type": "extraAgents", "user": address], as: [ExtraAgent].self)
    }

    static let fundingPageSize = 500

    /// Funding payments from `since` to now, across every DEX. The API returns
    /// at most `fundingPageSize` entries, oldest first, so a full page means
    /// there may be more: keep going from just after the last payment.
    func funding(address: String, since: Date) async throws -> [FundingPayment] {
        var payments: [FundingPayment] = []
        var startMs = Int(since.timeIntervalSince1970 * 1000)
        while true {
            let page = try await client.info(
                ["type": "userFunding", "user": address, "startTime": startMs],
                as: [FundingPayment].self
            )
            payments += page
            guard page.count >= Self.fundingPageSize, let last = page.last else { return payments }
            startMs = Int(last.time.timeIntervalSince1970 * 1000) + 1
        }
    }

    /// Which balances back this address's positions. Older nodes and testnet
    /// deployments may not serve `userAbstraction` at all, so an unusable
    /// response means "standard" rather than a failed snapshot.
    func abstraction(address: String) async -> AccountAbstraction {
        (try? await client.info(["type": "userAbstraction", "user": address],
                                as: AccountAbstraction.self)) ?? .standard
    }

    /// Clearinghouse state on every builder-deployed DEX where this wallet holds
    /// a position, keyed by DEX name. A DEX that fails or answers with nothing
    /// open is dropped rather than failing the whole snapshot — the core DEX and
    /// the spot balance are the parts a wallet screen can't render without.
    private func builderStates(address: String) async -> [String: PerpsState] {
        let names = await meta.builderDexNames()
        guard !names.isEmpty else { return [:] }

        return await withTaskGroup(of: (String, PerpsState?).self) { group in
            for dex in names {
                group.addTask {
                    let state = try? await client.info(
                        ["type": "clearinghouseState", "user": address, "dex": dex],
                        as: PerpsState.self
                    )
                    return (dex, state)
                }
            }
            var states: [String: PerpsState] = [:]
            for await (dex, state) in group {
                if let state, !state.openPositions.isEmpty { states[dex] = state }
            }
            return states
        }
    }

    /// Mids for each named DEX, keyed by DEX name. A DEX whose mids can't be
    /// fetched simply leaves its positions without a mark price.
    private func builderMids(for dexes: [String]) async -> [String: [String: Double]] {
        await withTaskGroup(of: (String, [String: Double]?).self) { group in
            for dex in dexes {
                group.addTask { (dex, try? await allMids(dex: dex)) }
            }
            var mids: [String: [String: Double]] = [:]
            for await (dex, dexMids) in group {
                if let dexMids { mids[dex] = dexMids }
            }
            return mids
        }
    }

    func snapshot(address: String) async throws -> WalletSnapshot {
        async let perps = client.info(["type": "clearinghouseState", "user": address], as: PerpsState.self)
        async let spot = client.info(["type": "spotClearinghouseState", "user": address], as: SpotState.self)
        async let orders = client.info(["type": "frontendOpenOrders", "user": address], as: [OpenOrder].self)
        async let coreMids = allMids()
        async let mode = abstraction(address: address)
        async let builders = builderStates(address: address)

        let spotState = try await spot
        var spotMidKeys: [String: String] = [:]
        for balance in spotState.nonZeroBalances where !balance.isUSDC {
            if let key = try? await meta.spotMidKey(coin: balance.coin) {
                spotMidKeys[balance.coin] = key
            }
        }

        // Mids are only worth fetching for DEXs that turned out to hold something.
        let builderPerps = await builders
        var mids = await builderMids(for: Array(builderPerps.keys))
        mids[""] = try await coreMids

        return try await WalletSnapshot(
            perps: perps, builderPerps: builderPerps,
            spot: spotState, openOrders: orders, abstraction: mode,
            mids: mids, spotMidKeys: spotMidKeys
        )
    }
}
