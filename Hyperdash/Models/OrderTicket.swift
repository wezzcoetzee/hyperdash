import Foundation

/// A new perp order as the ticket describes it, before the Trade Desk resolves
/// assets and prices it. Sized in dollars of notional; the desk converts to
/// coin size at the price the order will actually be sent at.
struct OrderTicket: Equatable {
    enum Kind: Equatable {
        case market
        case limit(price: Double)
    }

    var coin: String
    var isLong: Bool
    var kind: Kind
    /// Position notional in USD (margin × leverage).
    var notional: Double
    var leverage: Int
    /// Margin mode to set alongside leverage. Kept from an existing position so
    /// the ticket never silently flips isolated to cross.
    var isCross = true
    /// Distance from entry, as a fraction of price, for the attached triggers.
    var takeProfitMove: Double?
    var stopLossMove: Double?

    /// Hyperliquid rejects orders under $10 notional.
    static let minimumNotional = 10.0

    var margin: Double { notional / Double(max(leverage, 1)) }

    /// The price the order is sized and its triggers are placed against.
    func entryPrice(mark: Double) -> Double {
        switch kind {
        case .market: mark
        case .limit(let price): price
        }
    }

    func size(mark: Double) -> Double {
        let price = entryPrice(mark: mark)
        return price > 0 ? notional / price : 0
    }

    func takeProfitPrice(mark: Double) -> Double? {
        takeProfitMove.map { Protection.price(movingBy: $0, from: entryPrice(mark: mark), kind: .takeProfit, isLong: isLong) }
    }

    func stopLossPrice(mark: Double) -> Double? {
        stopLossMove.map { Protection.price(movingBy: $0, from: entryPrice(mark: mark), kind: .stopLoss, isLong: isLong) }
    }

    /// Why the ticket can't be sent as it stands, or nil when it can.
    func problem(available: Double, maxLeverage: Int) -> String? {
        if case .limit(let price) = kind, price <= 0 { return "Enter a limit price." }
        if notional < Self.minimumNotional { return "Minimum order is \(Format.usd(Self.minimumNotional, fractionDigits: 0))." }
        if !(1...max(maxLeverage, 1)).contains(leverage) { return "Max leverage for \(coin) is \(maxLeverage)x." }
        if margin > available { return "Needs \(Format.usd(margin)) margin, \(Format.usd(available)) available." }
        return nil
    }
}
