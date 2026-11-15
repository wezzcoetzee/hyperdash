import Foundation

/// Take-profit and stop-loss rules shared by the order ticket and the price
/// ladder. A trigger is only meaningful on one side of the reference price:
/// a long takes profit above it and stops out below it, a short the reverse.
enum Protection {
    enum Kind {
        case takeProfit
        case stopLoss
    }

    /// Whether `price` sits on the side of `reference` where `kind` belongs.
    /// A trigger on the wrong side would fire the moment it's placed.
    static func isValid(_ price: Double, kind: Kind, isLong: Bool, reference: Double) -> Bool {
        let above = price > reference
        let below = price < reference
        switch (kind, isLong) {
        case (.takeProfit, true), (.stopLoss, false): return above
        case (.takeProfit, false), (.stopLoss, true): return below
        }
    }

    static func price(movingBy move: Double, from reference: Double, kind: Kind, isLong: Bool) -> Double {
        let up = (kind == .takeProfit) == isLong
        return reference * (up ? 1 + move : 1 - move)
    }

    /// PnL of the whole position if it closed at `price`. `signedSize` is
    /// negative for a short.
    static func pnl(at price: Double, entry: Double, signedSize: Double) -> Double {
        (price - entry) * signedSize
    }

    /// The trigger orders already guarding `coin`: every reduce-only trigger,
    /// whether it was attached to the position or to the order that opened it.
    static func existingTriggers(for coin: String, in orders: [OpenOrder]) -> [OpenOrder] {
        orders.filter { $0.coin == coin && $0.isTrigger == true && $0.reduceOnly == true }
    }
}

extension OpenOrder {
    /// The price an existing trigger fires at, and whether it takes profit.
    /// Hyperliquid labels them "Take Profit Market", "Stop Market" and the
    /// limit variants.
    var protectionLevel: (price: Double, kind: Protection.Kind)? {
        guard isTrigger == true, let triggerPx else { return nil }
        let isTakeProfit = orderType?.localizedCaseInsensitiveContains("take profit") == true
        return (triggerPx.hlDouble, isTakeProfit ? .takeProfit : .stopLoss)
    }
}

/// Maps prices onto the price ladder's vertical axis, highest price at the
/// top. The range covers every level with padding, and never narrows below
/// ±5% of the mark, so a ladder near the mark still has room to drag.
struct LadderScale: Equatable {
    let low: Double
    let high: Double

    init(levels: [Double], mark: Double) {
        let prices = (levels + [mark * 0.95, mark * 1.05]).filter { $0 > 0 }
        let lo = prices.min() ?? 0
        let hi = prices.max() ?? 1
        let pad = (hi - lo) * 0.12
        low = max(0, lo - pad)
        high = hi + pad
    }

    /// 0 at the top of the axis, 1 at the bottom.
    func position(of price: Double) -> Double {
        guard high > low else { return 0.5 }
        return min(1, max(0, (high - price) / (high - low)))
    }

    func price(at position: Double) -> Double {
        high - min(1, max(0, position)) * (high - low)
    }
}
