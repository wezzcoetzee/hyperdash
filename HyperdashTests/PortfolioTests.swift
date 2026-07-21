import XCTest
@testable import Hyperdash

final class PortfolioTests: XCTestCase {

    private func decodePortfolio() throws -> PortfolioResponse {
        let data = Data(Fixtures.portfolio.utf8)
        return try JSONDecoder().decode(PortfolioResponse.self, from: data)
    }

    func testPortfolioDecodesPeriodKeys() throws {
        let portfolio = try decodePortfolio()
        for key in ["day", "week", "month", "allTime", "perpDay"] {
            XCTAssertTrue(portfolio.windows.keys.contains(key))
        }

        let week = portfolio.accountValueSeries(.week)
        XCTAssertEqual(week.count, 2)
        XCTAssertEqual(week.first?.value, 90)
        XCTAssertEqual(week.first?.date, Date(timeIntervalSince1970: 1))
    }

    func testInfoServicePortfolio() async throws {
        let session = HyperliquidSession(network: .testnet, transport: FixtureTransport(infoFixtures: [
            "portfolio": Fixtures.portfolio
        ]))
        let portfolio = try await session.info.portfolio(address: "0xabc")
        XCTAssertEqual(portfolio.pnlSeries(.day).last?.value, 10)
    }

    func testEmptyPeriodReturnsEmptySeries() throws {
        let portfolio = try decodePortfolio()
        XCTAssertEqual(portfolio.accountValueSeries(.month), [])
        XCTAssertEqual(portfolio.pnlSeries(.month), [])
    }
}
