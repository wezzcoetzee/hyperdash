import Foundation

/// Element of the `frontendOpenOrders` info response.
struct OpenOrder: Decodable, Identifiable {
    let coin: String
    let side: String
    let limitPx: String
    let sz: String
    let oid: Int
    let timestamp: Int
    let origSz: String?
    let orderType: String?
    let reduceOnly: Bool?
    let isTrigger: Bool?
    let triggerPx: String?
    let triggerCondition: String?
    let isPositionTpsl: Bool?

    var id: Int { oid }
    var isBuy: Bool { side.uppercased() == "B" }
    var sideLabel: String { isBuy ? "Buy" : "Sell" }
    var limitPrice: Double { limitPx.hlDouble }
    var size: Double { sz.hlDouble }
    var typeLabel: String { orderType ?? (isTrigger == true ? "Trigger" : "Limit") }
}
