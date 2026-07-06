import Foundation

/// A pending trade the user is about to confirm.
enum TradeContext: Identifiable {
    case closePosition(Position)
    case cancelOrder(OpenOrder)
    case sellSpot(SpotBalance)

    var id: String {
        switch self {
        case .closePosition(let p): return "close-\(p.coin)"
        case .cancelOrder(let o): return "cancel-\(o.oid)"
        case .sellSpot(let b): return "sell-\(b.id)"
        }
    }

    var title: String {
        switch self {
        case .closePosition(let p): return "Close \(p.directionLabel) \(p.coin)"
        case .cancelOrder(let o): return "Cancel \(o.coin) order"
        case .sellSpot(let b): return "Sell \(b.coin) → USDC"
        }
    }

    var actionVerb: String {
        switch self {
        case .closePosition: return "Close Position"
        case .cancelOrder: return "Cancel Order"
        case .sellSpot: return "Sell to USDC"
        }
    }

    var isDestructive: Bool { true }
}
