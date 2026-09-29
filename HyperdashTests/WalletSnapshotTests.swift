import XCTest
@testable import Hyperdash

final class WalletSnapshotTests: XCTestCase {

    private func makeSession(allMids: String, userAbstraction: String? = nil,
                             extraFixtures: [String: String] = [:]) -> HyperliquidSession {
        var fixtures = [
            "clearinghouseState": Fixtures.flatPerps,
            "spotClearinghouseState": Fixtures.spotWithPURR,
            "frontendOpenOrders": "[]",
            "allMids": allMids,
            "spotMeta": Fixtures.spotMeta
        ]
        fixtures["userAbstraction"] = userAbstraction
        fixtures.merge(extraFixtures) { _, new in new }
        return HyperliquidSession(network: .testnet, transport: FixtureTransport(infoFixtures: fixtures))
    }

    /// A wallet holding an equity position on the "xyz" HIP-3 dex. Its mids and
    /// clearinghouse state are dex-scoped; the core dex sees none of it.
    private func makeHIP3Session(userAbstraction: String? = nil) -> HyperliquidSession {
        makeSession(allMids: #"{"ETH": "2000.0", "@1": "0.5"}"#,
                    userAbstraction: userAbstraction,
                    extraFixtures: [
                        "perpDexs": Fixtures.perpDexs,
                        "clearinghouseState:xyz": Fixtures.xyzPerps,
                        "allMids:xyz": #"{"AAPL": "200.0"}"#
                    ])
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
        XCTAssertEqual(snapshot.abstraction, .standard)
        XCTAssertEqual(snapshot.totalAccountValue, 1105.0)
    }

    /// A unified account keeps the perp collateral inside the spot balance, so
    /// summing perps equity on top would count the same dollars twice.
    func testUnifiedAccountTotalIsSpotValueAlone() async throws {
        let session = makeSession(allMids: #"{"ETH": "2000.0", "@1": "0.5"}"#,
                                  userAbstraction: #""unifiedAccount""#)
        let snapshot = try await session.info.snapshot(address: "0xabc")

        XCTAssertEqual(snapshot.abstraction, .unifiedAccount)
        XCTAssertEqual(snapshot.perps.accountValue, 1000.0)
        XCTAssertEqual(snapshot.spotUSDValue, 105.0)
        XCTAssertEqual(snapshot.totalAccountValue, 105.0)
        XCTAssertEqual(snapshot.accountBalanceUSDC, 105.0)
    }

    /// Portfolio margin shares unified account's balance model, and an object
    /// wrapper is as valid a response shape as a bare string.
    func testPortfolioMarginDecodesFromObjectResponse() async throws {
        let session = makeSession(allMids: #"{"ETH": "2000.0", "@1": "0.5"}"#,
                                  userAbstraction: #"{"type": "portfolioMargin"}"#)
        let snapshot = try await session.info.snapshot(address: "0xabc")

        XCTAssertEqual(snapshot.abstraction, .portfolioMargin)
        XCTAssertEqual(snapshot.totalAccountValue, 105.0)
    }

    /// Nodes that don't serve `userAbstraction` must leave valuation unchanged
    /// rather than failing the snapshot.
    func testUnservedAbstractionFallsBackToStandard() async throws {
        let session = makeSession(allMids: #"{"ETH": "2000.0", "@1": "0.5"}"#,
                                  userAbstraction: #"{"unexpected": 1}"#)
        let snapshot = try await session.info.snapshot(address: "0xabc")

        XCTAssertEqual(snapshot.abstraction, .standard)
        XCTAssertEqual(snapshot.totalAccountValue, 1105.0)
    }

    func testUnpricedSpotBalanceHasNoUSDValue() async throws {
        let session = makeSession(allMids: #"{"ETH": "2000.0"}"#)
        let snapshot = try await session.info.snapshot(address: "0xabc")

        let purr = try XCTUnwrap(snapshot.spot.nonZeroBalances.first { $0.coin == "PURR" })
        XCTAssertNil(snapshot.usdValue(of: purr))
        XCTAssertEqual(snapshot.spotUSDValue, 100.0)
    }

    /// Positions on a builder-deployed dex live in their own clearinghouse, so
    /// without a dex-scoped request they never reach the wallet screen at all.
    func testBuilderDexPositionsAppearWithTheirOwnMark() async throws {
        let snapshot = try await makeHIP3Session().info.snapshot(address: "0xabc")

        let aapl = try XCTUnwrap(snapshot.openPositions.first { $0.position.coin == "AAPL" })
        XCTAssertEqual(aapl.dex, "xyz")
        XCTAssertFalse(aapl.isCore)
        XCTAssertEqual(snapshot.mark(for: aapl), 200.0)
        XCTAssertEqual(snapshot.totalUnrealizedPnl, 100.0)
        XCTAssertEqual(snapshot.sideExposure.total, 2000.0)
        XCTAssertEqual(snapshot.sideExposure.long.count, 1)
    }

    /// Under unified account the spot balance already carries the collateral
    /// backing every dex, so a builder dex's margin summary must not be added on.
    func testUnifiedAccountIgnoresBuilderDexAccountValue() async throws {
        let session = makeHIP3Session(userAbstraction: #""unifiedAccount""#)
        let snapshot = try await session.info.snapshot(address: "0xabc")

        XCTAssertEqual(snapshot.perpsAccountValue, 1000.0)
        XCTAssertEqual(snapshot.totalAccountValue, 105.0)
        XCTAssertEqual(snapshot.openPositions.count, 1)
    }

    /// A standard account does keep a separate balance per clearinghouse, so
    /// there the builder dex's equity is a real addend.
    func testStandardAccountSumsBuilderDexEquityAndMargin() async throws {
        let snapshot = try await makeHIP3Session().info.snapshot(address: "0xabc")

        XCTAssertEqual(snapshot.abstraction, .standard)
        XCTAssertEqual(snapshot.perpsAccountValue, 1500.0)
        XCTAssertEqual(snapshot.totalAccountValue, 1605.0)
        XCTAssertEqual(snapshot.totalMarginUsed, 200.0)
        XCTAssertEqual(snapshot.maintenanceMarginUsed, 50.0)
    }

    /// A node that doesn't serve `perpDexs` leaves the core-dex snapshot intact.
    func testMissingPerpDexsLeavesSnapshotUnchanged() async throws {
        let session = makeSession(allMids: #"{"ETH": "2000.0", "@1": "0.5"}"#)
        let snapshot = try await session.info.snapshot(address: "0xabc")

        XCTAssertTrue(snapshot.builderPerps.isEmpty)
        XCTAssertEqual(snapshot.totalAccountValue, 1105.0)
    }

    private func corePosition(coin: String) throws -> DexPosition {
        let json = Fixtures.longETHPosition.replacingOccurrences(of: #""coin": "ETH""#,
                                                                with: #""coin": "\#(coin)""#)
        return DexPosition(dex: "", position: try JSONDecoder().decode(Position.self, from: Data(json.utf8)))
    }

    func testPerpMarkIsKeyedByCoin() async throws {
        let session = makeSession(allMids: #"{"ETH": "2000.0", "@1": "0.5"}"#)
        let snapshot = try await session.info.snapshot(address: "0xabc")

        XCTAssertEqual(snapshot.mark(for: try corePosition(coin: "ETH")), 2000.0)
        XCTAssertNil(snapshot.mark(for: try corePosition(coin: "DOGE")))
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
