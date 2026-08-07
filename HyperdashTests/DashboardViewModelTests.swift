import XCTest
@testable import Hyperdash

@MainActor
final class DashboardViewModelTests: XCTestCase {

    /// Answers `/info` by request "type", but fails `clearinghouseState` for one
    /// target address so a single wallet's snapshot throws while others succeed.
    private struct PerAddressTransport: HTTPTransport {
        var infoFixtures: [String: String]
        var failingSnapshotAddress: String?

        func post(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
            let body = request.httpBody
                .flatMap { try? JSONSerialization.jsonObject(with: $0) as? [String: Any] } ?? [:]
            let type = body["type"] as? String
            let user = body["user"] as? String

            if type == "clearinghouseState", let user, user == failingSnapshotAddress {
                let http = HTTPURLResponse(url: request.url!, statusCode: 503,
                                           httpVersion: nil, headerFields: nil)!
                return (Data("service unavailable".utf8), http)
            }

            let json = type.flatMap { infoFixtures[$0] } ?? "{}"
            let http = HTTPURLResponse(url: request.url!, statusCode: 200,
                                       httpVersion: nil, headerFields: nil)!
            return (Data(json.utf8), http)
        }
    }

    private let goodAddress = "0x00000000000000000000000000000000000000a1"
    private let failAddress = "0x00000000000000000000000000000000000000b2"

    private func session(failing: String?) -> HyperliquidSession {
        HyperliquidSession(network: .testnet, transport: PerAddressTransport(
            infoFixtures: [
                "clearinghouseState": Fixtures.flatPerps,
                "spotClearinghouseState": Fixtures.spotWithPURR,
                "frontendOpenOrders": "[]",
                "allMids": #"{"ETH": "2000.0", "@1": "0.5"}"#,
                "spotMeta": Fixtures.spotMeta,
                "portfolio": Fixtures.portfolio
            ],
            failingSnapshotAddress: failing
        ))
    }

    func testPartialSnapshotFailureStillLoadsHealthyWallets() async {
        let model = DashboardViewModel()
        let wallets = [
            Wallet(name: "Good", address: goodAddress),
            Wallet(name: "Broken", address: failAddress)
        ]

        await model.load(wallets: wallets, session: session(failing: failAddress))

        XCTAssertEqual(model.state, .loaded)
        XCTAssertTrue(model.hasLoaded)
        XCTAssertEqual(model.totals.walletCount, 1)
        XCTAssertEqual(model.portfolios.count, 1)
        XCTAssertGreaterThan(model.totals.balance, 0)
    }

    func testSurfacesTopWinnerFromPositivePnL() async {
        let model = DashboardViewModel()
        let wallets = [Wallet(name: "Good", address: goodAddress)]

        await model.load(wallets: wallets, session: session(failing: nil))

        let winner = try? XCTUnwrap(model.topWinner)
        XCTAssertEqual(winner?.name, "Good")
        XCTAssertGreaterThan(winner?.pnl ?? 0, 0)
        XCTAssertGreaterThan(winner?.pnlPercent ?? 0, 0)
        // A single wallet can't be both winner and loser.
        XCTAssertNil(model.topLoser)
    }

    func testMergesSpotHoldingsAcrossWallets() async {
        let model = DashboardViewModel()
        let wallets = [
            Wallet(name: "One", address: goodAddress),
            Wallet(name: "Two", address: "0x00000000000000000000000000000000000000c3")
        ]

        await model.load(wallets: wallets, session: session(failing: nil))

        // Both wallets answer with the same spot fixture, so every coin appears
        // once at double the single-wallet amount.
        XCTAssertEqual(Set(model.spotHoldings.map(\.coin)).count, model.spotHoldings.count)
        let purr = model.spotHoldings.first { $0.coin == "PURR" }
        XCTAssertEqual(purr?.walletCount, 2)

        let single = DashboardViewModel()
        await single.load(wallets: [wallets[0]], session: session(failing: nil))
        let singlePurr = single.spotHoldings.first { $0.coin == "PURR" }
        XCTAssertEqual(purr?.amount ?? 0, (singlePurr?.amount ?? 0) * 2, accuracy: 0.0001)
        XCTAssertEqual(purr?.usdValue ?? 0, (singlePurr?.usdValue ?? 0) * 2, accuracy: 0.0001)
    }

    func testSpotHoldingsSortedByValueDescending() async {
        let model = DashboardViewModel()
        await model.load(wallets: [Wallet(name: "One", address: goodAddress)],
                         session: session(failing: nil))

        let values = model.spotHoldings.map { $0.usdValue ?? 0 }
        XCTAssertEqual(values, values.sorted(by: >))
    }

    func testAllSnapshotsFailingReportsError() async {
        let model = DashboardViewModel()
        let wallets = [Wallet(name: "Broken", address: failAddress)]

        await model.load(wallets: wallets, session: session(failing: failAddress))

        guard case .failed = model.state else {
            return XCTFail("Expected .failed when every wallet snapshot fails, got \(model.state)")
        }
        XCTAssertFalse(model.hasLoaded)
    }

    func testTransientFailureAfterGoodLoadKeepsPriorData() async {
        let model = DashboardViewModel()
        let wallets = [Wallet(name: "Good", address: goodAddress)]

        await model.load(wallets: wallets, session: session(failing: nil))
        XCTAssertEqual(model.state, .loaded)
        let loadedBalance = model.totals.balance
        XCTAssertGreaterThan(loadedBalance, 0)

        await model.load(wallets: wallets, session: session(failing: goodAddress))

        guard case .failed = model.state else {
            return XCTFail("Expected .failed after a transient reload failure")
        }
        XCTAssertTrue(model.hasLoaded)
        XCTAssertEqual(model.totals.balance, loadedBalance)
        XCTAssertEqual(model.portfolios.count, 1)
    }
}
