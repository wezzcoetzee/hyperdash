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

    static func orderAction(
        asset: AssetInfo,
        isBuy: Bool,
        price: Double,
        size: Double,
        reduceOnly: Bool
    ) -> MsgPackValue {
        let order = MsgPackValue.map([
            ("a", .int(asset.assetId)),
            ("b", .bool(isBuy)),
            ("p", .string(Wire.price(price, szDecimals: asset.szDecimals, isSpot: asset.isSpot))),
            ("s", .string(Wire.size(size, szDecimals: asset.szDecimals))),
            ("r", .bool(reduceOnly)),
            ("t", .map([("limit", .map([("tif", .string("Ioc"))]))]))
        ])
        return .map([
            ("type", .string("order")),
            ("orders", .array([order])),
            ("grouping", .string("na"))
        ])
    }

    static func cancelAction(assetId: Int, oid: Int) -> MsgPackValue {
        .map([
            ("type", .string("cancel")),
            ("cancels", .array([.map([("a", .int(assetId)), ("o", .int(oid))])]))
        ])
    }
}
