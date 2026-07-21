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
}
