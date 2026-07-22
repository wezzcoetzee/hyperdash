import Foundation

/// A pending trade the user is about to confirm.
enum TradeContext: Identifiable {
    case closePosition(Position)
    case cancelOrder(OpenOrder)
    case sellSpot(SpotBalance)
    case closeAll(positions: [Position], orders: [OpenOrder])

    var id: String {
        switch self {
        case .closePosition(let p): return "close-\(p.coin)"
        case .cancelOrder(let o): return "cancel-\(o.oid)"
        case .sellSpot(let b): return "sell-\(b.id)"
        case .closeAll: return "close-all"
        }
    }

    var title: String {
        switch self {
        case .closePosition(let p): return "Close \(p.directionLabel) \(p.coin)"
        case .cancelOrder(let o): return "Cancel \(o.coin) order"
        case .sellSpot(let b): return "Sell \(b.coin) → USDC"
        case .closeAll: return "Close all positions & orders"
        }
    }

    var actionVerb: String {
        switch self {
        case .closePosition: return "Close Position"
        case .cancelOrder: return "Cancel Order"
        case .sellSpot: return "Sell to USDC"
        case .closeAll: return "Close Everything"
        }
    }

    var isDestructive: Bool { true }
}
