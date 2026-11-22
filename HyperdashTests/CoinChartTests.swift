import XCTest
@testable import Hyperdash

final class CoinChartTests: XCTestCase {
    private let candleJSON = #"""
    [
      {"t": 1700000000000, "T": 1700000899999, "s": "ETH", "i": "15m",
       "o": "1800.5", "c": "1810.25", "h": "1815", "l": "1795.75", "v": "42.5", "n": 120},
      {"t": 1700000900000, "T": 1700001799999, "s": "ETH", "i": "15m",
       "o": "1810.25", "c": "1790", "h": "1812", "l": "1788", "v": "10", "n": 80}
    ]
    """#

    func testCandleDecodesStringFields() async throws {
        let session = HyperliquidSession(network: .testnet, transport: FixtureTransport(infoFixtures: [
            "candleSnapshot": candleJSON
        ]))
        let candles = try await session.info.candles(coin: "ETH", range: .day)
        XCTAssertEqual(candles.count, 2)
        XCTAssertEqual(candles[0].open, 1800.5)
        XCTAssertEqual(candles[0].close, 1810.25)
        XCTAssertEqual(candles[0].high, 1815)
        XCTAssertEqual(candles[0].low, 1795.75)
        XCTAssertEqual(candles[0].volume, 42.5)
        XCTAssertEqual(candles[0].openTime, Date(timeIntervalSince1970: 1_700_000_000))
        XCTAssertTrue(candles[0].isGain)
        XCTAssertFalse(candles[1].isGain)
    }

    func testUnparseablePriceIsAnErrorNotAZero() {
        let bad = #"[{"t": 1, "T": 2, "o": "oops", "c": "1", "h": "1", "l": "1", "v": "1"}]"#
        XCTAssertThrowsError(try JSONDecoder().decode([Candle].self, from: Data(bad.utf8)))
    }

    func testChangeRunsFirstOpenToLastClose() throws {
        func candle(open: Double, close: Double) -> Candle {
            Candle(openTime: .distantPast, closeTime: .distantFuture, open: open, high: max(open, close),
                   low: min(open, close), close: close, volume: 0)
        }
        let change = try XCTUnwrap(PriceChange(over: [
            candle(open: 100, close: 130), candle(open: 130, close: 90), candle(open: 90, close: 110),
        ]))
        XCTAssertEqual(change.absolute, 10)
        XCTAssertEqual(try XCTUnwrap(change.percent), 10, accuracy: 1e-9)
        XCTAssertNil(PriceChange(over: []))
    }

    private let metaAndCtxs = #"""
    [
      {"universe": [{"name": "BTC", "szDecimals": 5}, {"name": "ETH", "szDecimals": 4}]},
      [
        {"funding": "0.00001", "openInterest": "100", "dayNtlVlm": "5000", "markPx": "60000", "prevDayPx": "59000"},
        {"funding": "-0.0000125", "openInterest": "2000", "dayNtlVlm": "750000.5", "markPx": "1800", "prevDayPx": "1700"}
      ]
    ]
    """#

    func testStatsComeFromTheCoinsUniverseIndex() async throws {
        let session = HyperliquidSession(network: .testnet, transport: FixtureTransport(infoFixtures: [
            "metaAndAssetCtxs": metaAndCtxs
        ]))
        let ethStats = try await session.info.coinStats(coin: "ETH")
        let eth = try XCTUnwrap(ethStats)
        XCTAssertEqual(eth.markPrice, 1800)
        XCTAssertEqual(eth.hourlyFunding, -0.0000125)
        XCTAssertEqual(eth.dayVolumeUSD, 750_000.5)

        let btcStats = try await session.info.coinStats(coin: "BTC")
        let btc = try XCTUnwrap(btcStats)
        XCTAssertEqual(btc.markPrice, 60000)

        let missing = try await session.info.coinStats(coin: "DOGE")
        XCTAssertNil(missing)
    }

}
