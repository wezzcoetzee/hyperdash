import Foundation

/// Response of the `clearinghouseState` info request (perpetuals account state).
struct PerpsState: Decodable {
    let marginSummary: MarginSummary
    let crossMarginSummary: MarginSummary
    let crossMaintenanceMarginUsed: String
    let withdrawable: String
    let assetPositions: [AssetPosition]
    let time: Int?

    var accountValue: Double { marginSummary.accountValue.hlDouble }
    var totalMarginUsed: Double { marginSummary.totalMarginUsed.hlDouble }

    /// `crossMaintenanceMarginUsed` only covers cross-margined positions, so isolated
    /// positions' maintenance margin (notional / (2 * maxLeverage), Hyperliquid's default
    /// maintenance fraction) must be added in separately to get the account-wide total.
    var maintenanceMarginUsed: Double {
        let isolatedMaintenance = openPositions
            .filter { $0.leverage.type == "isolated" }
            .reduce(0.0) { $0 + $1.notionalValue / (2 * Double($1.maxLeverage)) }
        return crossMaintenanceMarginUsed.hlDouble + isolatedMaintenance
    }

    var withdrawableValue: Double { withdrawable.hlDouble }

    var openPositions: [Position] {
        assetPositions.map(\.position).filter { $0.size != 0 }
    }
}

struct MarginSummary: Decodable {
    let accountValue: String
    let totalNtlPos: String
    let totalRawUsd: String
    let totalMarginUsed: String
}

struct AssetPosition: Decodable {
    let type: String
    let position: Position
}

struct Position: Decodable {
    let coin: String
    let szi: String
    let entryPx: String?
    let positionValue: String
    let unrealizedPnl: String
    let returnOnEquity: String
    let liquidationPx: String?
    let marginUsed: String
    let maxLeverage: Int
    let leverage: Leverage
    let cumFunding: CumulativeFunding

    struct Leverage: Decodable {
        let type: String
        let value: Int
        let rawUsd: String?
    }

    struct CumulativeFunding: Decodable {
        let allTime: String
        let sinceOpen: String
        let sinceChange: String
    }

    /// Signed size. Negative means short.
    var size: Double { szi.hlDouble }
    var isLong: Bool { size >= 0 }
    var absoluteSize: Double { abs(size) }
    var directionLabel: String { isLong ? "LONG" : "SHORT" }

    var entryPrice: Double? { entryPx?.hlDouble }
    var notionalValue: Double { positionValue.hlDouble }
    var unrealizedPnlValue: Double { unrealizedPnl.hlDouble }
    var returnOnEquityValue: Double { returnOnEquity.hlDouble }
    var liquidationPrice: Double? { liquidationPx?.hlDouble }
    var marginUsedValue: Double { marginUsed.hlDouble }
    var fundingSinceOpen: Double { cumFunding.sinceOpen.hlDouble }

    /// Percentage distance from the given mark price to the liquidation price.
    func liquidationDistancePct(markPrice: Double) -> Double? {
        guard let liq = liquidationPrice, liq > 0, markPrice > 0 else { return nil }
        return abs(markPrice - liq) / markPrice * 100
    }
}
