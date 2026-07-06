import XCTest
@testable import Hyperdash

final class WalletSnapshotTests: XCTestCase {

    private func makeSession(allMids: String) -> HyperliquidSession {
        HyperliquidSession(network: .testnet, transport: FixtureTransport(infoFixtures: [
            "clearinghouseState": Fixtures.flatPerps,
            "spotClearinghouseState": Fixtures.spotWithPURR,
            "frontendOpenOrders": "[]",
            "allMids": allMids,
            "spotMeta": Fixtures.spotMeta
        ]))
    }

    /// Spot mids live under "@<pair index>" in allMids, not under the coin
    /// name. The snapshot must resolve PURR → "@1" to value the balance.
    func testSpotValuationResolvesPairMidKey() async throws {
        let session = makeSession(allMids: #"{"ETH": "2000.0", "@1": "0.5"}"#)
        let snapshot = try await session.info.snapshot(address: "0xabc")

        let purr = try XCTUnwrap(snapshot.spot.nonZeroBalances.first { $0.coin == "PURR" })
        XCTAssertEqual(snapshot.usdValue(of: purr), 5.0)

        let usdc = try XCTUnwrap(snapshot.spot.nonZeroBalances.first { $0.coin == "USDC" })
        XCTAssertEqual(snapshot.usdValue(of: usdc), 100.0)

        XCTAssertEqual(snapshot.spotUSDValue, 105.0)
        XCTAssertEqual(snapshot.totalAccountValue, 1105.0)
    }

    func testUnpricedSpotBalanceHasNoUSDValue() async throws {
        let session = makeSession(allMids: #"{"ETH": "2000.0"}"#)
        let snapshot = try await session.info.snapshot(address: "0xabc")

        let purr = try XCTUnwrap(snapshot.spot.nonZeroBalances.first { $0.coin == "PURR" })
        XCTAssertNil(snapshot.usdValue(of: purr))
        XCTAssertEqual(snapshot.spotUSDValue, 100.0)
    }

    func testPerpMarkIsKeyedByCoin() async throws {
        let session = makeSession(allMids: #"{"ETH": "2000.0", "@1": "0.5"}"#)
        let snapshot = try await session.info.snapshot(address: "0xabc")

        XCTAssertEqual(snapshot.mark(for: "ETH"), 2000.0)
        XCTAssertNil(snapshot.mark(for: "DOGE"))
    }
}
