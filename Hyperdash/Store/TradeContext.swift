import Foundation

/// A pending trade the user is about to confirm.
enum TradeContext: Identifiable {
    /// `fraction` of the position to close, from 0 (exclusive) to 1.
    case closePosition(Position, fraction: Double = 1)
    case cancelOrder(OpenOrder)
    case sellSpot(SpotBalance)
    case closeAll(positions: [Position], orders: [OpenOrder])
    case openPosition(OrderTicket)
    /// Places position TP/SL triggers (nil means none) and cancels `replacing`,
    /// the triggers already guarding the position.
    case setProtection(Position, takeProfit: Double?, stopLoss: Double?, replacing: [OpenOrder])

    var id: String {
        switch self {
        case .closePosition(let p, _): return "close-\(p.coin)"
        case .cancelOrder(let o): return "cancel-\(o.oid)"
        case .sellSpot(let b): return "sell-\(b.id)"
        case .closeAll: return "close-all"
        case .openPosition(let t): return "open-\(t.coin)-\(t.isLong)"
        case .setProtection(let p, _, _, _): return "tpsl-\(p.coin)"
        }
    }

    var title: String {
        switch self {
        case .closePosition(let p, _): return "Close \(p.directionLabel) \(p.coin)"
        case .cancelOrder(let o): return "Cancel \(o.coin) order"
        case .sellSpot(let b): return "Sell \(b.coin) → USDC"
        case .closeAll: return "Close all positions & orders"
        case .openPosition(let t): return "\(t.isLong ? "Long" : "Short") \(t.coin)"
        case .setProtection(let p, _, _, _): return "TP/SL \(p.coin)"
        }
    }

    var actionVerb: String {
        switch self {
        case .closePosition(_, let fraction):
            return fraction < 1 ? "Close \(Format.percent(fraction * 100, fractionDigits: 0))" : "Close Position"
        case .cancelOrder: return "Cancel Order"
        case .sellSpot: return "Sell to USDC"
        case .closeAll: return "Close Everything"
        case .openPosition(let t): return "Open \(t.isLong ? "Long" : "Short")"
        case .setProtection: return "Set TP/SL"
        }
    }

    /// Exits and cancellations take the red destructive button; opening a
    /// position or protecting one does not.
    var isDestructive: Bool {
        switch self {
        case .openPosition, .setProtection: false
        default: true
        }
    }
}
