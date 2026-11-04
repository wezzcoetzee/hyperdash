import XCTest
@testable import Hyperdash

final class DayChangeTests: XCTestCase {

    private func points(_ values: [Double]) -> [PortfolioPoint] {
        values.enumerated().map { PortfolioPoint(date: Date(timeIntervalSince1970: Double($0.offset)), value: $0.element) }
    }

    /// A deposit lifts account value but not PnL, so it must not read as a gain.
    func testChangeComesFromPnlNotAccountValue() throws {
        let change = try XCTUnwrap(DayChange(dayPnl: points([20, 35, 70]), value: 1050))
        XCTAssertEqual(change.amount, 50)
        XCTAssertEqual(try XCTUnwrap(change.percent), 50.0 / 1000 * 100, accuracy: 1e-9)
    }

    func testOrdersHistoryByDate() throws {
        let shuffled = [PortfolioPoint(date: Date(timeIntervalSince1970: 2), value: 10),
                        PortfolioPoint(date: Date(timeIntervalSince1970: 1), value: 40)]
        XCTAssertEqual(DayChange(dayPnl: shuffled, value: 100)?.amount, -30)
    }

    func testTooShortHistoryHasNoChange() {
        XCTAssertNil(DayChange(dayPnl: [], value: 100))
        XCTAssertNil(DayChange(dayPnl: points([5]), value: 100))
    }

    /// A wallet funded from zero today has no base to measure a percentage from.
    func testNoPercentWithoutPositiveBase() {
        XCTAssertNil(DayChange(amount: 100, value: 100).percent)
        XCTAssertNil(DayChange(amount: 150, value: 100).percent)
    }

    func testCombinedWeightsByValue() throws {
        let combined = try XCTUnwrap(DayChange.combined([
            DayChange(amount: 100, value: 1100),  // +10%
            DayChange(amount: -10, value: 90)     // -10%
        ]))
        XCTAssertEqual(combined.amount, 90)
        XCTAssertEqual(combined.value, 1190)
        XCTAssertEqual(try XCTUnwrap(combined.percent), 90.0 / 1100 * 100, accuracy: 1e-9)
        XCTAssertNil(DayChange.combined([]))
    }

    func testUpdatedLabelText() {
        let now = Date(timeIntervalSince1970: 10_000)
        XCTAssertEqual(UpdatedLabel.text(since: now.addingTimeInterval(-3), now: now), "Updated just now")
        XCTAssertEqual(UpdatedLabel.text(since: now.addingTimeInterval(-42), now: now), "Updated 42s ago")
        XCTAssertEqual(UpdatedLabel.text(since: now.addingTimeInterval(-185), now: now), "Updated 3m ago")
        XCTAssertEqual(UpdatedLabel.text(since: now.addingTimeInterval(-7300), now: now), "Updated 2h ago")
    }
}
