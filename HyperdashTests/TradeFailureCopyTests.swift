import XCTest
@testable import Hyperdash

/// The failure screen is read at the worst possible moment, so the mapping from
/// Hyperliquid's terse strings to plain guidance is worth pinning down.
final class TradeFailureCopyTests: XCTestCase {

    private func humanized(_ raw: String) -> String {
        TradeConfirmationView.humanizedFailure(raw)
    }

    func testMarginShortfallOutranksTheGenericBalanceMessage() {
        let message = humanized("Insufficient margin to place order")
        XCTAssertTrue(message.contains("margin"))
        XCTAssertTrue(message.contains("add funds"))
    }

    func testGenericInsufficientBalance() {
        let message = humanized("Insufficient balance for requested operation")
        XCTAssertTrue(message.contains("Not enough balance"))
        XCTAssertFalse(message.contains("margin"))
    }

    func testReduceOnlyRejection() {
        for raw in ["Order would increase position (reduce only)",
                    "reduce-only order rejected"] {
            XCTAssertTrue(humanized(raw).contains("reduce-only"), raw)
        }
    }

    func testPostOnlyRejection() {
        for raw in ["Post only order would have immediately matched",
                    "post-only rejected"] {
            XCTAssertTrue(humanized(raw).contains("rests on the book"), raw)
        }
    }

    func testZeroSizeRejection() {
        XCTAssertTrue(humanized("Order has zero size").contains("rounds to zero"))
        XCTAssertTrue(humanized("Size must be greater than 0").contains("rounds to zero"))
    }

    func testRateLimiting() {
        XCTAssertTrue(humanized("HTTP 429").contains("rate-limiting"))
        XCTAssertTrue(humanized("rate limit exceeded").contains("rate-limiting"))
    }

    func testMatchingIsCaseInsensitive() {
        XCTAssertEqual(humanized("INSUFFICIENT MARGIN"), humanized("insufficient margin"))
    }

    func testUnknownFailuresPassThroughUnchanged() {
        // Better a terse true message than a confident wrong one.
        let raw = "Exchange returned error code 7734"
        XCTAssertEqual(humanized(raw), raw)
    }
}
