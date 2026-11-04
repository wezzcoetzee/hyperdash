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

    /// Loads `wallets` into a fresh shared cache and derives the dashboard from it,
    /// the same way `DashboardView` does.
    private func load(_ wallets: [Wallet], failing: String? = nil,
                      into existing: WalletDataStore? = nil) async -> (WalletDataStore, DashboardViewModel) {
        let store = existing ?? WalletDataStore()
        await store.load(wallets: wallets, session: session(failing: failing))
        let model = DashboardViewModel()
        model.update(wallets: wallets, data: store.data)
        return (store, model)
    }

    func testPartialSnapshotFailureStillLoadsHealthyWallets() async {
        let wallets = [
            Wallet(name: "Good", address: goodAddress),
            Wallet(name: "Broken", address: failAddress)
        ]

        let (store, model) = await load(wallets, failing: failAddress)

        XCTAssertEqual(store.state, .loaded)
        XCTAssertEqual(store.data.count, 1)
        XCTAssertEqual(model.totals.walletCount, 1)
        XCTAssertEqual(model.portfolios.count, 1)
        XCTAssertGreaterThan(model.totals.balance, 0)
    }

    func testSurfacesTopWinnerFromPositivePnL() async {
        let (_, model) = await load([Wallet(name: "Good", address: goodAddress)])

        let winner = try? XCTUnwrap(model.topWinner)
        XCTAssertEqual(winner?.name, "Good")
        XCTAssertGreaterThan(winner?.pnl ?? 0, 0)
        XCTAssertGreaterThan(winner?.pnlPercent ?? 0, 0)
        // A single wallet can't be both winner and loser.
        XCTAssertNil(model.topLoser)
    }

    func testMergesSpotHoldingsAcrossWallets() async {
        let wallets = [
            Wallet(name: "One", address: goodAddress),
            Wallet(name: "Two", address: "0x00000000000000000000000000000000000000c3")
        ]

        let (store, model) = await load(wallets)

        // Both wallets answer with the same spot fixture, so every coin appears
        // once at double the single-wallet amount.
        XCTAssertEqual(Set(model.spotHoldings.map(\.coin)).count, model.spotHoldings.count)
        let purr = model.spotHoldings.first { $0.coin == "PURR" }
        XCTAssertEqual(purr?.walletCount, 2)

        // Deriving from just one wallet of the same cache halves it.
        let single = DashboardViewModel()
        single.update(wallets: [wallets[0]], data: store.data)
        let singlePurr = single.spotHoldings.first { $0.coin == "PURR" }
        XCTAssertEqual(purr?.amount ?? 0, (singlePurr?.amount ?? 0) * 2, accuracy: 0.0001)
        XCTAssertEqual(purr?.usdValue ?? 0, (singlePurr?.usdValue ?? 0) * 2, accuracy: 0.0001)
    }

    func testSpotHoldingsSortedByValueDescending() async {
        let (_, model) = await load([Wallet(name: "One", address: goodAddress)])

        let values = model.spotHoldings.map { $0.usdValue ?? 0 }
        XCTAssertEqual(values, values.sorted(by: >))
    }

    func testAllSnapshotsFailingReportsError() async {
        let (store, model) = await load([Wallet(name: "Broken", address: failAddress)], failing: failAddress)

        guard case .failed = store.state else {
            return XCTFail("Expected .failed when every wallet snapshot fails, got \(store.state)")
        }
        XCTAssertFalse(store.hasData)
        XCTAssertEqual(model.totals.walletCount, 0)
    }

    func testTransientFailureAfterGoodLoadKeepsPriorData() async {
        let wallets = [Wallet(name: "Good", address: goodAddress)]
        let (store, first) = await load(wallets)
        XCTAssertEqual(store.state, .loaded)
        let loadedBalance = first.totals.balance
        XCTAssertGreaterThan(loadedBalance, 0)

        let (_, model) = await load(wallets, failing: goodAddress, into: store)

        guard case .failed = store.state else {
            return XCTFail("Expected .failed after a transient reload failure")
        }
        XCTAssertTrue(store.hasData)
        XCTAssertEqual(model.totals.balance, loadedBalance)
        XCTAssertEqual(model.portfolios.count, 1)
    }

    func testRemovedWalletsArePrunedFromCache() async {
        let keep = Wallet(name: "Keep", address: goodAddress)
        let drop = Wallet(name: "Drop", address: "0x00000000000000000000000000000000000000c3")
        let (store, _) = await load([keep, drop])
        XCTAssertEqual(store.data.count, 2)

        await store.load(wallets: [keep], session: session(failing: nil))

        XCTAssertEqual(Set(store.data.keys), [keep.id])
    }

    func testSwitchingNetworkClearsCache() async {
        let wallets = [Wallet(name: "Good", address: goodAddress)]
        let (store, _) = await load(wallets)
        XCTAssertTrue(store.hasData)

        let mainnet = HyperliquidSession(network: .mainnet, transport: PerAddressTransport(
            infoFixtures: [:], failingSnapshotAddress: goodAddress))
        await store.load(wallets: wallets, session: mainnet)

        XCTAssertFalse(store.hasData)
    }

    func testDayChangeUsesDayPnlWindow() async throws {
        let wallet = Wallet(name: "Good", address: goodAddress)
        let (store, _) = await load([wallet])

        // The fixture's day pnlHistory runs 0 -> 10.
        let change = try XCTUnwrap(store.data[wallet.id]?.dayChange)
        XCTAssertEqual(change.amount, 10)
    }
}
