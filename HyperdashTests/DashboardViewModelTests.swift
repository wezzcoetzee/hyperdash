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
