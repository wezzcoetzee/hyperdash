import XCTest
@testable import Hyperdash

final class PortfolioAggregatorTests: XCTestCase {

    private func point(_ ts: TimeInterval, _ value: Double) -> PortfolioPoint {
        PortfolioPoint(date: Date(timeIntervalSince1970: ts), value: value)
    }

    func testSumAlignsDisjointTimestamps() {
        let a = [point(1, 100), point(3, 120)]
        let b = [point(2, 50)]

        let result = PortfolioAggregator.sum([a, b])

        XCTAssertEqual(result, [point(1, 100), point(2, 150), point(3, 170)])
    }

    func testSumEmptyInputsReturnsEmpty() {
        XCTAssertEqual(PortfolioAggregator.sum([]), [])
        XCTAssertEqual(PortfolioAggregator.sum([[], []]), [])
    }

    func testSingleSeriesPassthrough() {
        let a = [point(1, 100), point(2, 200)]
        XCTAssertEqual(PortfolioAggregator.sum([a, []]), a)
    }

    // MARK: - Flat lead-in trimming

    /// The `allTime` shape: a long unfunded run, then the account comes alive.
    private func fundedLate() -> [PortfolioPoint] {
        let dead = (0..<40).map { point(TimeInterval($0), 0) }
        let live = (40..<60).map { point(TimeInterval($0), Double($0) * 1_000) }
        return dead + live
    }

    func testTrimsFlatLeadInKeepingOnePointOfLead() {
        let trimmed = PortfolioAggregator.trimmingFlatLeadIn(fundedLate())

        // One flat point survives so the ramp reads as a ramp, not a cliff.
        XCTAssertEqual(trimmed.first, point(38, 0))
        XCTAssertEqual(trimmed.last, point(59, 59_000))
        XCTAssertEqual(trimmed.count, 22)
    }

    func testTrimToleratesSmallDriftInTheDeadRun() {
        // A dead run that wobbles well under 3% of the full range still counts.
        let dead = (0..<40).map { point(TimeInterval($0), Double($0 % 3) * 100) }
        let live = (40..<60).map { point(TimeInterval($0), Double($0) * 1_000) }

        let trimmed = PortfolioAggregator.trimmingFlatLeadIn(dead + live)

        XCTAssertLessThan(trimmed.count, 60)
        XCTAssertEqual(trimmed.last, point(59, 59_000))
    }

    func testActiveSeriesIsUntouched() {
        let active = (0..<60).map { point(TimeInterval($0), Double($0) * 100) }
        XCTAssertEqual(PortfolioAggregator.trimmingFlatLeadIn(active), active)
    }

    func testShortOrConstantSeriesAreUntouched() {
        let short = [point(1, 0), point(2, 0), point(3, 500)]
        XCTAssertEqual(PortfolioAggregator.trimmingFlatLeadIn(short), short)

        let constant = (0..<30).map { point(TimeInterval($0), 250) }
        XCTAssertEqual(PortfolioAggregator.trimmingFlatLeadIn(constant), constant)
    }

    func testAlwaysLeavesEnoughPointsToPlot() {
        // Flat right up to the last two readings; the floor keeps the chart
        // from collapsing to a single segment.
        let dead = (0..<98).map { point(TimeInterval($0), 0) }
        let live = (98..<100).map { point(TimeInterval($0), Double($0) * 1_000) }

        let trimmed = PortfolioAggregator.trimmingFlatLeadIn(dead + live)

        XCTAssertEqual(trimmed.count, 8)
        XCTAssertEqual(trimmed.last, point(99, 99_000))
    }
}
