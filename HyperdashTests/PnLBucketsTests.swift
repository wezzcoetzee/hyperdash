import XCTest
@testable import Hyperdash

final class PnLBucketsTests: XCTestCase {

    private var calendar: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "UTC")!
        return c
    }()

    private func point(day: Int, hour: Int = 0, _ value: Double) -> PortfolioPoint {
        let date = calendar.date(from: DateComponents(year: 2026, month: 1, day: day, hour: hour))!
        return PortfolioPoint(date: date, value: value)
    }

    func testDailyDeltasDifferenceBucketCloses() {
        let points = [point(day: 1, 0), point(day: 1, hour: 12, 10),
                      point(day: 2, hour: 6, 4), point(day: 3, 25)]

        let bars = PnLBuckets.bars(from: points, unit: .day, calendar: calendar)

        XCTAssertEqual(bars.map(\.delta), [10, -6, 21])
        XCTAssertEqual(bars.map(\.date), [point(day: 1, 0), point(day: 2, 0), point(day: 3, 0)].map(\.date))
    }

    func testFirstBucketIsMeasuredFromOpeningValue() {
        let points = [point(day: 1, 100), point(day: 1, hour: 5, 130)]
        XCTAssertEqual(PnLBuckets.bars(from: points, unit: .day, calendar: calendar).map(\.delta), [30])
    }

    func testDeltasSumToTotalChange() {
        let points = [point(day: 1, 5), point(day: 2, 12), point(day: 3, -4), point(day: 4, 9)]
        let total = PnLBuckets.bars(from: points, unit: .day, calendar: calendar).map(\.delta).reduce(0, +)
        XCTAssertEqual(total, 4, accuracy: 1e-9)
    }

    func testEmptySeriesHasNoBars() {
        XCTAssertEqual(PnLBuckets.bars(from: [], unit: .day, calendar: calendar), [])
    }

    func testUnitPerPeriod() {
        XCTAssertEqual(PnLBuckets.unit(for: .day, points: []), .hour)
        XCTAssertEqual(PnLBuckets.unit(for: .week, points: []), .day)
        let long = [point(day: 1, 0), PortfolioPoint(date: point(day: 1, 0).date.addingTimeInterval(200 * 86_400), value: 1)]
        XCTAssertEqual(PnLBuckets.unit(for: .allTime, points: long), .month)
        XCTAssertEqual(PnLBuckets.unit(for: .allTime, points: [point(day: 1, 0), point(day: 9, 1)]), .day)
    }
}
