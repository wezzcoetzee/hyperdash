import XCTest
@testable import Hyperdash

final class FillsPaginationTests: XCTestCase {
    /// Serves `userFillsByTime` pages by the request's `startTime`.
    private struct PagedTransport: HTTPTransport {
        let pages: [Int: String]

        func post(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
            let body = request.httpBody.flatMap { try? JSONSerialization.jsonObject(with: $0) as? [String: Any] }
            let start = body?["startTime"] as? Int ?? -1
            let http = HTTPURLResponse(url: URL(fileURLWithPath: "/"), statusCode: 200, httpVersion: nil, headerFields: nil)
            return (Data((pages[start] ?? "[]").utf8), http ?? HTTPURLResponse())
        }
    }

    private func json(tid: Int, time: Int) -> String {
        #"{"tid": \#(tid), "coin": "BTC", "px": "1", "sz": "1", "side": "B", "time": \#(time), "dir": "Buy", "closedPnl": "0", "fee": "0", "feeToken": "USDC"}"#
    }

    func testBoundaryMillisecondFillsAreNotLostOrDuplicated() async throws {
        let size = InfoService.fillsPageSize
        // The first page ends with two fills at t=5000; the second starts there,
        // repeats them, and adds a third that the page cap cut off.
        let first = (1...size).map { json(tid: $0, time: $0 < size - 1 ? 1000 + $0 : 5000) }
        let second = [size - 1, size, size + 1].map { json(tid: $0, time: 5000) }
        let session = HyperliquidSession(network: .testnet, transport: PagedTransport(pages: [
            1000: "[" + first.joined(separator: ",") + "]",
            5000: "[" + second.joined(separator: ",") + "]"
        ]))
        let fills = try await session.info.fills(address: "0xabc", startMs: 1000, endMs: 9000)
        XCTAssertEqual(fills.count, size + 1)
        XCTAssertEqual(Set(fills.map(\.tid)).count, size + 1)
    }
}
