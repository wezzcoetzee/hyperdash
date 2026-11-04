import XCTest
@testable import Hyperdash

final class WidgetDataTests: XCTestCase {

    private func point(_ ts: TimeInterval, _ value: Double) -> PortfolioPoint {
        PortfolioPoint(date: Date(timeIntervalSince1970: ts), value: value)
    }

    private func portfolio(values: [PortfolioPoint], pnl: [PortfolioPoint]) -> PortfolioResponse {
        PortfolioResponse(windows: ["day": PortfolioWindow(accountValueHistory: values, pnlHistory: pnl)])
    }

    // MARK: - PortfolioSummary

    func testSummaryTotalsValueAndWeightsDayChange() throws {
        let a = portfolio(values: [point(1, 900), point(2, 1000)], pnl: [point(1, 0), point(2, 100)])
        let b = portfolio(values: [point(1, 500)], pnl: [point(1, 0), point(2, -50)])

        let summary = PortfolioSummary([(value: 1000, portfolio: a), (value: 500, portfolio: b)])

        XCTAssertEqual(summary.value, 1500)
        let change = try XCTUnwrap(summary.dayChange)
        XCTAssertEqual(change.amount, 50)
        XCTAssertEqual(try XCTUnwrap(change.percent), 50.0 / 1450 * 100, accuracy: 1e-9)
        XCTAssertEqual(summary.dayHistory, [point(1, 1400), point(2, 1500)])
    }

    /// A wallet with no day history still counts toward value, just not the change.
    func testSummaryWithoutHistoryHasNoChange() {
        let summary = PortfolioSummary([(value: 250, portfolio: PortfolioResponse(windows: [:]))])
        XCTAssertEqual(summary.value, 250)
        XCTAssertNil(summary.dayChange)
        XCTAssertEqual(summary.dayHistory, [])
    }

    // MARK: - WidgetFeed

    private func scratchDefaults() -> UserDefaults {
        let suite = "WidgetDataTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        addTeardownBlock { defaults.removePersistentDomain(forName: suite) }
        return defaults
    }

    func testFeedRoundTripsAndSkipsUnchangedWrites() {
        let defaults = scratchDefaults()
        let feed = WidgetFeed(addresses: ["0xbb", "0xaa", "0xbb"], network: .testnet)

        XCTAssertTrue(feed.publish(to: defaults))
        XCTAssertEqual(WidgetFeed(defaults: defaults), feed)
        XCTAssertEqual(feed.addresses, ["0xaa", "0xbb"])

        // Reordering wallets is the same feed, so the widget isn't reloaded.
        XCTAssertFalse(WidgetFeed(addresses: ["0xaa", "0xbb"], network: .testnet).publish(to: defaults))
        XCTAssertTrue(WidgetFeed(addresses: ["0xaa", "0xbb"], network: .mainnet).publish(to: defaults))
    }

    func testPrivacyModeReadsSharedKey() {
        let defaults = scratchDefaults()
        XCTAssertFalse(SharedDefaults.privacyMode(in: defaults))
        defaults.set(true, forKey: "privacyMode")
        XCTAssertTrue(SharedDefaults.privacyMode(in: defaults))
    }
}
