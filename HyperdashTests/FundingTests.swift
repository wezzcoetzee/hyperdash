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

/// Serves a full first page, then a short second page, recording each startTime.
private final class PagedFundingTransport: HTTPTransport, @unchecked Sendable {
    private let lock = NSLock()
    private var starts: [Int] = []
    var startTimes: [Int] { lock.withLock { starts } }

    func post(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        let body = try JSONSerialization.jsonObject(with: request.httpBody ?? Data()) as? [String: Any]
        let start = body?["startTime"] as? Int ?? 0
        let first = lock.withLock { starts.append(start); return starts.count == 1 }
        let times = first ? Array(0..<InfoService.fundingPageSize).map { 1_000 + $0 } : [9_000]
        let rows = times.map {
            #"{"time": \#($0), "delta": {"type": "funding", "coin": "ETH", "usdc": "1"}}"#
        }
        let http = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
        return (Data("[\(rows.joined(separator: ","))]".utf8), http)
    }
}

extension FundingTests {
    func testFundingPagesPastTheFiveHundredEntryCap() async throws {
        let transport = PagedFundingTransport()
        let session = HyperliquidSession(network: .testnet, transport: transport)
        let payments = try await session.info.funding(address: "0xabc", since: .distantPast)
        XCTAssertEqual(payments.count, InfoService.fundingPageSize + 1)
        XCTAssertEqual(transport.startTimes.last, 1_000 + InfoService.fundingPageSize)
    }
}
