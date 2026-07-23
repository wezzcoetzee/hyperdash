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

    func testAccountLeverageUsesDisplayedBalanceAndOpenPositionExposure() throws {
        let perpsJSON = #"""
        {
          "marginSummary": {"accountValue": "8208.30", "totalNtlPos": "71400", "totalRawUsd": "0", "totalMarginUsed": "0"},
          "crossMarginSummary": {"accountValue": "8208.30", "totalNtlPos": "71400", "totalRawUsd": "0", "totalMarginUsed": "0"},
          "crossMaintenanceMarginUsed": "0",
          "withdrawable": "0",
          "assetPositions": [
            {"type": "oneWay", "position": {
              "coin": "ETH", "szi": "1", "entryPx": "22500", "positionValue": "22500",
              "unrealizedPnl": "0", "returnOnEquity": "0", "liquidationPx": null,
              "marginUsed": "0", "maxLeverage": 50,
              "leverage": {"type": "cross", "value": 10},
              "cumFunding": {"allTime": "0", "sinceOpen": "0", "sinceChange": "0"}
            }}
          ],
          "time": 0
        }
        """#
        let spotJSON = #"""
        {"balances": []}
        """#
        let perps = try JSONDecoder().decode(PerpsState.self, from: Data(perpsJSON.utf8))
        let spot = try JSONDecoder().decode(SpotState.self, from: Data(spotJSON.utf8))
        let snapshot = WalletSnapshot(
            perps: perps,
            spot: spot,
            openOrders: [],
            mids: [:],
            spotMidKeys: [:]
        )

        XCTAssertEqual(snapshot.accountBalanceUSDC, 8208.30, accuracy: 0.001)
        XCTAssertEqual(snapshot.sideExposure.total, 22_500, accuracy: 0.001)
        XCTAssertEqual(snapshot.accountLeverage, 22_500 / 8208.30, accuracy: 0.001)
    }
}
