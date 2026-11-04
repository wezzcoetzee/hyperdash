import Foundation

/// Identifies a group of positions across wallets: same market (coin on a DEX)
/// and same side. Hashable so it can be a navigation value that is resolved
/// against live data, never a stale copy of the group.
struct PositionGroupKey: Hashable {
    /// Empty for the core perp DEX.
    let dex: String
    let coin: String
    let isLong: Bool
}

/// Every wallet's position in one market and side, rolled up.
struct PositionGroup: Identifiable {
    struct Holding: Identifiable {
        let wallet: Wallet
        let position: Position
        /// Percent of mark between the mark and liquidation price.
        let liquidationPct: Double?

        var id: UUID { wallet.id }
    }

    let key: PositionGroupKey
    /// Largest notional first.
    let holdings: [Holding]

    var id: PositionGroupKey { key }
    var walletCount: Int { holdings.count }
    var totalSize: Double { holdings.reduce(0) { $0 + $1.position.absoluteSize } }
    var unrealizedPnl: Double { holdings.reduce(0) { $0 + $1.position.unrealizedPnlValue } }
    var nearestLiquidationPct: Double? { holdings.compactMap(\.liquidationPct).min() }
    private var totalNotional: Double { holdings.reduce(0) { $0 + $1.position.notionalValue } }

    /// Groups the open positions of every wallet that has data. Closest to
    /// liquidation first (groups with no liquidation price last), ties by notional.
    static func groups(wallets: [Wallet], data: [UUID: WalletData]) -> [PositionGroup] {
        var holdings: [PositionGroupKey: [Holding]] = [:]
        for wallet in wallets {
            guard let snapshot = data[wallet.id]?.snapshot else { continue }
            for entry in snapshot.openPositions {
                let position = entry.position
                let key = PositionGroupKey(dex: entry.dex, coin: position.coin, isLong: position.isLong)
                let liq = snapshot.mark(for: entry).flatMap { position.liquidationDistancePct(markPrice: $0) }
                holdings[key, default: []].append(Holding(wallet: wallet, position: position, liquidationPct: liq))
            }
        }
        return holdings.map { key, held in
            PositionGroup(key: key, holdings: held.sorted { $0.position.notionalValue > $1.position.notionalValue })
        }
        .sorted { lhs, rhs in
            switch (lhs.nearestLiquidationPct, rhs.nearestLiquidationPct) {
            case let (l?, r?) where l != r: return l < r
            case (_?, nil): return true
            case (nil, _?): return false
            default: return lhs.totalNotional > rhs.totalNotional
            }
        }
    }
}
