import XCTest
@testable import Hyperdash

final class PortfolioTests: XCTestCase {

    func testPortfolioDecodesPeriodKeys() throws {
        let portfolio = try JSONDecoder().decode(PortfolioResponse.self, from: Data(Fixtures.portfolio.utf8))
        XCTAssertEqual(Set(portfolio.windows.keys), ["day", "week", "month", "allTime", "perpDay"])

        let week = portfolio.accountValueSeries(.week)
        XCTAssertEqual(week.count, 2)
        XCTAssertEqual(week.first?.value, 90)
        XCTAssertEqual(week.first?.date, Date(timeIntervalSince1970: 1))
    }
}
