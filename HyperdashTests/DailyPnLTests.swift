import XCTest
@testable import Hyperdash

final class DailyPnLTests: XCTestCase {
    private let calendar: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(secondsFromGMT: 2 * 3600) ?? .gmt
        return c
    }()

    private func localDate(_ month: Int, _ day: Int, hour: Int = 12, minute: Int = 0) -> Date {
        calendar.date(from: DateComponents(year: 2025, month: month, day: day, hour: hour, minute: minute)) ?? .distantPast
    }

    /// A fill at a local wall-clock time in November 2025 (the 1st is a Saturday).
    private func fill(day: Int, hour: Int = 12, minute: Int = 0, pnl: Double = 0, fee: Double = 0,
                      feeToken: String? = "USDC") -> Fill {
        Fill(coin: "BTC", price: 100, size: 1, isBuy: true,
             timeMs: Int(localDate(11, day, hour: hour, minute: minute).timeIntervalSince1970 * 1000),
             dir: "Close Long", closedPnl: pnl, fee: fee, feeToken: feeToken)
    }

    private func month(_ fills: [Fill]) -> ActivityMonth {
        ActivityMonth(fills: fills, containing: localDate(11, 15), calendar: calendar)
    }

    func testFillsBucketByLocalDayAcrossMidnight() {
        let m = month([fill(day: 14, hour: 23, minute: 59, pnl: 10), fill(day: 15, hour: 0, minute: 0, pnl: 5)])
        XCTAssertEqual(m.pnl(on: localDate(11, 14))?.closedPnl, 10)
        XCTAssertEqual(m.pnl(on: localDate(11, 15))?.closedPnl, 5)
    }

    func testFillsOutsideMonthAreDropped() {
        let stray = Fill(coin: "ETH", price: 1, size: 1, isBuy: false,
                         timeMs: Int(localDate(10, 31, hour: 23, minute: 59).timeIntervalSince1970 * 1000),
                         dir: "Sell", closedPnl: 99, fee: 0)
        XCTAssertEqual(month([stray, fill(day: 1, pnl: 1)]).net, 1)
    }

    func testNetIsClosedPnlMinusFee() {
        let day = month([fill(day: 3, pnl: 100, fee: 1.5), fill(day: 3, pnl: -20, fee: 0.5)]).pnl(on: localDate(11, 3))
        XCTAssertEqual(day?.closedPnl, 80)
        XCTAssertEqual(day?.fees, 2)
        XCTAssertEqual(day?.net, 78)
    }

    func testNonUSDCFeesAreExcludedFromDollarFees() {
        let day = month([fill(day: 3, pnl: 10, fee: 1), fill(day: 3, fee: 500, feeToken: "HYPE")]).pnl(on: localDate(11, 3))
        XCTAssertEqual(day?.fees, 1)
        XCTAssertEqual(day?.net, 9)
    }

    func testMondayFirstLeadingBlanksForSaturdayStart() {
        let m = month([])
        XCTAssertEqual(m.leadingBlanks, 5)
        XCTAssertEqual(m.monthDays.count, 30)
    }

    func testMondayFirstLeadingBlanksForMondayStart() {
        // September 2025 starts on a Monday.
        XCTAssertEqual(ActivityMonth(fills: [], containing: localDate(9, 10), calendar: calendar).leadingBlanks, 0)
    }

    func testTintOpacityScalesAndClamps() {
        let m = month([fill(day: 1, pnl: 1000), fill(day: 2, pnl: -500), fill(day: 3, pnl: 1), fill(day: 4, pnl: 0)])
        XCTAssertEqual(m.tintOpacity(for: 1000), 0.85)
        XCTAssertEqual(m.tintOpacity(for: -500) ?? 0, 0.5, accuracy: 1e-9)
        XCTAssertEqual(m.tintOpacity(for: 1), 0.15)
        XCTAssertNil(m.tintOpacity(for: 0))
    }
}
