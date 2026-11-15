import XCTest
@testable import Hyperdash

final class ProtectionTests: XCTestCase {

    func testTriggersOnlyBelongOnTheirSideOfReference() {
        XCTAssertTrue(Protection.isValid(110, kind: .takeProfit, isLong: true, reference: 100))
        XCTAssertFalse(Protection.isValid(90, kind: .takeProfit, isLong: true, reference: 100))
        XCTAssertTrue(Protection.isValid(90, kind: .stopLoss, isLong: true, reference: 100))
        XCTAssertTrue(Protection.isValid(90, kind: .takeProfit, isLong: false, reference: 100))
        XCTAssertTrue(Protection.isValid(110, kind: .stopLoss, isLong: false, reference: 100))
        XCTAssertFalse(Protection.isValid(100, kind: .stopLoss, isLong: false, reference: 100))
    }

    func testMovesAreMirroredForShorts() {
        XCTAssertEqual(Protection.price(movingBy: 0.1, from: 100, kind: .takeProfit, isLong: true), 110, accuracy: 1e-9)
        XCTAssertEqual(Protection.price(movingBy: 0.1, from: 100, kind: .takeProfit, isLong: false), 90, accuracy: 1e-9)
        XCTAssertEqual(Protection.price(movingBy: 0.05, from: 100, kind: .stopLoss, isLong: false), 105, accuracy: 1e-9)
    }

    func testShortProfitsAsPriceFalls() {
        XCTAssertEqual(Protection.pnl(at: 90, entry: 100, signedSize: -2), 20, accuracy: 1e-9)
    }

    func testExistingTriggersIgnoreRestingLimitsAndOtherCoins() throws {
        let orders = try JSONDecoder().decode([OpenOrder].self, from: Data(#"""
        [
          {"coin": "ETH", "side": "A", "limitPx": "0", "sz": "1", "oid": 1, "timestamp": 0,
           "orderType": "Take Profit Market", "reduceOnly": true, "isTrigger": true, "triggerPx": "2500"},
          {"coin": "ETH", "side": "B", "limitPx": "1500", "sz": "1", "oid": 2, "timestamp": 0},
          {"coin": "BTC", "side": "A", "limitPx": "0", "sz": "1", "oid": 3, "timestamp": 0,
           "orderType": "Stop Market", "reduceOnly": true, "isTrigger": true, "triggerPx": "90000"}
        ]
        """#.utf8))

        let triggers = Protection.existingTriggers(for: "ETH", in: orders)

        XCTAssertEqual(triggers.map(\.oid), [1])
        let level = try XCTUnwrap(triggers.first?.protectionLevel)
        XCTAssertEqual(level.price, 2500)
        XCTAssertEqual(level.kind, .takeProfit)
    }

    func testLadderMapsPricesTopDownAndBack() {
        let scale = LadderScale(levels: [80, 120], mark: 100)

        XCTAssertLessThan(scale.position(of: 120), scale.position(of: 100))
        XCTAssertLessThan(scale.position(of: 100), scale.position(of: 80))
        XCTAssertEqual(scale.price(at: scale.position(of: 93)), 93, accuracy: 1e-9)
    }

    func testLadderKeepsRoomAroundTheMark() {
        let scale = LadderScale(levels: [], mark: 100)
        XCTAssertLessThan(scale.low, 95)
        XCTAssertGreaterThan(scale.high, 105)
    }
}
