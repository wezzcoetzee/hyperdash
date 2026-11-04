import XCTest
@testable import Hyperdash

final class FundingTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_700_010_000)

    private let userFunding = #"""
    [
      {"time": 1700000000000, "hash": "0x0", "delta": {"type": "funding", "coin": "ETH", "usdc": "-2.5", "szi": "1.5", "fundingRate": "0.0000125", "nSamples": null}},
      {"time": 1700003600000, "hash": "0x0", "delta": {"type": "funding", "coin": "BTC", "usdc": "1.0", "szi": "-0.1", "fundingRate": "0.00001"}}
    ]
    """#

    func testInfoServiceDecodesUserFunding() async throws {
        let session = HyperliquidSession(network: .testnet, transport: FixtureTransport(infoFixtures: [
            "userFunding": userFunding
        ]))
        let payments = try await session.info.funding(address: "0xabc", since: .distantPast)
        XCTAssertEqual(payments.map(\.coin), ["ETH", "BTC"])
        XCTAssertEqual(payments.map(\.usdc), [-2.5, 1.0])
        XCTAssertEqual(payments[0].time, Date(timeIntervalSince1970: 1_700_000_000))
    }

    func testNoHistoryYieldsNoSummary() {
        XCTAssertNil(FundingSummary(payments: [], now: now))
    }

    func testWindowsAndCoinOrdering() {
        let old = now.addingTimeInterval(-3 * 24 * 3600)
        let summary = FundingSummary(payments: [
            FundingPayment(time: now, coin: "ETH", usdc: -2),
            FundingPayment(time: now, coin: "BTC", usdc: 1),
            FundingPayment(time: old, coin: "ETH", usdc: -3),
        ], now: now)
        XCTAssertEqual(summary?.net24h, -1)
        XCTAssertEqual(summary?.net7d, -4)
        XCTAssertEqual(summary?.byCoin, [.init(coin: "ETH", net: -5), .init(coin: "BTC", net: 1)])
    }

    func testCoinsBeyondTopFiveFoldIntoOther() {
        let payments = (1...7).map { FundingPayment(time: now, coin: "C\($0)", usdc: Double($0)) }
        let byCoin = FundingSummary(payments: payments, now: now)?.byCoin
        XCTAssertEqual(byCoin?.count, 6)
        XCTAssertEqual(byCoin?.last, .init(coin: "Other", net: 3))
    }
}
