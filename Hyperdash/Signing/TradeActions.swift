import Foundation

/// Builds ordered `MsgPackValue` actions for the `/exchange` endpoint.
/// Field order is significant and matches the reference SDK exactly.
enum TradeActions {
    static let defaultSlippage = 0.05

    /// How an order rests (or doesn't) once it reaches the book.
    enum OrderKind {
        /// Fills what it can immediately and cancels the rest. Priced through
        /// the book, this is how the app sends market orders.
        case ioc
        /// Rests on the book until filled or cancelled.
        case gtc
        /// A market take-profit or stop-loss that fires at `triggerPrice`.
        case trigger(triggerPrice: Double, isTakeProfit: Bool)
    }

    /// How the orders in one action relate. `normalTpsl` attaches TP/SL
    /// children to an entry order; `positionTpsl` attaches them to the
    /// position itself, so they resize as it does.
    enum Grouping: String {
        case na
        case normalTpsl
        case positionTpsl
    }

    /// A market-style close/sell is an IOC limit order priced aggressively
    /// through the book so it fills immediately.
    static func aggressivePrice(mark: Double, isBuy: Bool, slippage: Double = defaultSlippage) -> Double {
        isBuy ? mark * (1 + slippage) : mark * (1 - slippage)
    }

    /// A single order in the wire format shared by one-off and bulk actions.
    static func orderEntry(
        asset: AssetInfo,
        isBuy: Bool,
        price: Double,
        size: Double,
        reduceOnly: Bool,
        kind: OrderKind = .ioc
    ) -> MsgPackValue {
        .map([
            ("a", .int(asset.assetId)),
            ("b", .bool(isBuy)),
            ("p", .string(Wire.price(price, szDecimals: asset.szDecimals, isSpot: asset.isSpot))),
            ("s", .string(Wire.size(size, szDecimals: asset.szDecimals))),
            ("r", .bool(reduceOnly)),
            ("t", orderType(kind, asset: asset))
        ])
    }

    private static func orderType(_ kind: OrderKind, asset: AssetInfo) -> MsgPackValue {
        switch kind {
        case .ioc:
            return .map([("limit", .map([("tif", .string("Ioc"))]))])
        case .gtc:
            return .map([("limit", .map([("tif", .string("Gtc"))]))])
        case .trigger(let triggerPrice, let isTakeProfit):
            return .map([("trigger", .map([
                ("isMarket", .bool(true)),
                ("triggerPx", .string(Wire.price(triggerPrice, szDecimals: asset.szDecimals, isSpot: asset.isSpot))),
                ("tpsl", .string(isTakeProfit ? "tp" : "sl"))
            ]))])
        }
    }

    static func orderAction(
        asset: AssetInfo,
        isBuy: Bool,
        price: Double,
        size: Double,
        reduceOnly: Bool
    ) -> MsgPackValue {
        ordersAction([orderEntry(asset: asset, isBuy: isBuy, price: price, size: size, reduceOnly: reduceOnly)])
    }

    /// Batches several orders into one signed action.
    static func ordersAction(_ orders: [MsgPackValue], grouping: Grouping = .na) -> MsgPackValue {
        .map([
            ("type", .string("order")),
            ("orders", .array(orders)),
            ("grouping", .string(grouping.rawValue))
        ])
    }

    static func cancelAction(assetId: Int, oid: Int) -> MsgPackValue {
        cancelsAction([(assetId: assetId, oid: oid)])
    }

    /// Batches several cancels into one signed action.
    static func cancelsAction(_ cancels: [(assetId: Int, oid: Int)]) -> MsgPackValue {
        .map([
            ("type", .string("cancel")),
            ("cancels", .array(cancels.map { .map([("a", .int($0.assetId)), ("o", .int($0.oid))]) }))
        ])
    }

    static func updateLeverageAction(assetId: Int, isCross: Bool, leverage: Int) -> MsgPackValue {
        .map([
            ("type", .string("updateLeverage")),
            ("asset", .int(assetId)),
            ("isCross", .bool(isCross)),
            ("leverage", .int(leverage))
        ])
    }
}
