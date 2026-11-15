import XCTest
@testable import Hyperdash

final class OrderTicketTests: XCTestCase {

    private func ticket(notional: Double, leverage: Int = 10) -> OrderTicket {
        OrderTicket(coin: "ETH", isLong: true, kind: .market, notional: notional, leverage: leverage)
    }

    func testRejectsOrdersUnderTheExchangeMinimum() {
        XCTAssertEqual(ticket(notional: 9).problem(available: 1000, maxLeverage: 50), "Minimum order is $10.")
    }

    func testRejectsMarginBeyondWhatsAvailable() {
        XCTAssertNotNil(ticket(notional: 2000, leverage: 10).problem(available: 100, maxLeverage: 50))
        XCTAssertNil(ticket(notional: 1000, leverage: 10).problem(available: 100, maxLeverage: 50))
    }

    func testLimitTriggersAnchorOnTheLimitPrice() {
        var limit = ticket(notional: 1000)
        limit.kind = .limit(price: 1000)
        limit.takeProfitMove = 0.1
        XCTAssertEqual(limit.takeProfitPrice(mark: 2000) ?? 0, 1100, accuracy: 1e-9)
        XCTAssertEqual(limit.size(mark: 2000), 1, accuracy: 1e-9)
    }

    func testKeypadDropsLeadingZerosAndCapsDecimals() {
        var entry = KeypadEntry(maxFractionDigits: 2)
        for key: KeypadEntry.Key in [.digit(0), .digit(5), .point, .digit(1), .digit(2), .digit(9)] {
            entry.press(key)
        }
        XCTAssertEqual(entry.text, "5.12")

        entry.press(.delete)
        entry.press(.point)
        XCTAssertEqual(entry.text, "5.1")
    }

    func testKeypadPointOnEmptyStartsWithZero() {
        var entry = KeypadEntry(maxFractionDigits: 2)
        entry.press(.point)
        XCTAssertEqual(entry.text, "0.")
    }
}
