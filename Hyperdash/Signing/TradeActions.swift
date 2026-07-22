import Foundation

/// Builds ordered `MsgPackValue` actions for the `/exchange` endpoint.
/// Field order is significant and matches the reference SDK exactly.
enum TradeActions {
    static let defaultSlippage = 0.05

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
        reduceOnly: Bool
    ) -> MsgPackValue {
        .map([
            ("a", .int(asset.assetId)),
            ("b", .bool(isBuy)),
            ("p", .string(Wire.price(price, szDecimals: asset.szDecimals, isSpot: asset.isSpot))),
            ("s", .string(Wire.size(size, szDecimals: asset.szDecimals))),
            ("r", .bool(reduceOnly)),
            ("t", .map([("limit", .map([("tif", .string("Ioc"))]))]))
        ])
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
    static func ordersAction(_ orders: [MsgPackValue]) -> MsgPackValue {
        .map([
            ("type", .string("order")),
            ("orders", .array(orders)),
            ("grouping", .string("na"))
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
}
