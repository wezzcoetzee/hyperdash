import XCTest
@testable import Hyperdash

final class LiveMidsTests: XCTestCase {

    private func decodePosition(_ json: String) throws -> Position {
        try JSONDecoder().decode(Position.self, from: Data(json.utf8))
    }

    func testRepricedLongPosition() throws {
        let position = try decodePosition(Fixtures.longETHPosition).repriced(mark: 2100)

        XCTAssertEqual(position.unrealizedPnlValue, 450, accuracy: 1e-9)
        XCTAssertEqual(position.notionalValue, 3150, accuracy: 1e-9)
        // Entry margin: 1.5 × 1,800 / 10x = 270.
        XCTAssertEqual(position.returnOnEquityValue, 450.0 / 270.0, accuracy: 1e-9)
        XCTAssertEqual(position.liquidationPrice, 100)
    }

    func testRepricedShortPositionGainsWhenMarkFalls() throws {
        let short = try decodePosition(#"""
        {
          "coin": "ETH", "szi": "-2", "entryPx": "100", "positionValue": "200",
          "unrealizedPnl": "0", "returnOnEquity": "0", "liquidationPx": "150",
          "marginUsed": "20", "maxLeverage": 10,
          "leverage": {"type": "cross", "value": 10},
          "cumFunding": {"allTime": "0", "sinceOpen": "0", "sinceChange": "0"}
        }
        """#)

        let repriced = short.repriced(mark: 90)

        XCTAssertEqual(repriced.unrealizedPnlValue, 20, accuracy: 1e-9)
        XCTAssertEqual(repriced.notionalValue, 180, accuracy: 1e-9)
        XCTAssertEqual(repriced.returnOnEquityValue, 1.0, accuracy: 1e-9)
    }

    func testRepricedSnapshotLeavesBuilderDexAndUntouchedKeysAlone() async throws {
        let ethPerps = Fixtures.flatPerps.replacingOccurrences(
            of: #""assetPositions": []"#,
            with: #""assetPositions": [{"type": "oneWay", "position": \#(Fixtures.longETHPosition)}]"#
        )
        let session = HyperliquidSession(network: .testnet, transport: FixtureTransport(infoFixtures: [
            "clearinghouseState": ethPerps,
            "clearinghouseState:xyz": Fixtures.xyzPerps,
            "spotClearinghouseState": Fixtures.spotWithPURR,
            "frontendOpenOrders": "[]",
            "allMids": #"{"ETH": "2000.0", "@1": "0.5"}"#,
            "allMids:xyz": #"{"AAPL": "200.0"}"#,
            "perpDexs": Fixtures.perpDexs,
            "spotMeta": Fixtures.spotMeta
        ]))
        let snapshot = try await session.info.snapshot(address: "0xabc")

        let repriced = snapshot.repriced(coreMids: ["ETH": 2100])

        let eth = try XCTUnwrap(repriced.openPositions.first { $0.dex.isEmpty })
        XCTAssertEqual(repriced.mark(for: eth), 2100)
        XCTAssertEqual(eth.position.unrealizedPnlValue, 450, accuracy: 1e-9)

        let aapl = try XCTUnwrap(repriced.openPositions.first { $0.dex == "xyz" })
        XCTAssertEqual(repriced.mark(for: aapl), 200)
        XCTAssertEqual(aapl.position.unrealizedPnlValue, 100)

        // "@1" was absent from the update, so the spot valuation keeps its last mid.
        XCTAssertEqual(repriced.spotUSDValue, snapshot.spotUSDValue)

        let spotRepriced = snapshot.repriced(coreMids: ["@1": 1.0])
        XCTAssertEqual(spotRepriced.spotUSDValue, 110.0)
        XCTAssertEqual(spotRepriced.mark(for: try XCTUnwrap(spotRepriced.openPositions.first { $0.dex.isEmpty })), 2000)
    }

    func testDecodesAllMidsMessage() {
        let message = #"{"channel":"allMids","data":{"mids":{"BTC":"65000.5","@1":"0.5"}}}"#
        XCTAssertEqual(MidsFeed.decodeMids(Data(message.utf8)), ["BTC": 65000.5, "@1": 0.5])
    }

    func testIgnoresOtherChannels() {
        let ignored = [
            #"{"channel":"pong"}"#,
            #"{"channel":"subscriptionResponse","data":{"method":"subscribe","subscription":{"type":"allMids"}}}"#,
            #"{"channel":"trades","data":[]}"#,
        ]
        for message in ignored {
            XCTAssertNil(MidsFeed.decodeMids(Data(message.utf8)), message)
        }
    }
}
