import XCTest
@testable import Hyperdash

final class AgentKeyExpiryTests: XCTestCase {

    private let now = Date(timeIntervalSince1970: 1_700_000_000)

    func testStatusThresholds() {
        let warning = AgentKeyExpiry(validUntil: now.addingTimeInterval(3 * 86_400), source: .onChain)
        XCTAssertEqual(warning.status(now: now), .warning)
        XCTAssertEqual(warning.daysRemaining(now: now), 3)

        let healthy = AgentKeyExpiry(validUntil: now.addingTimeInterval(30 * 86_400), source: .onChain)
        XCTAssertEqual(healthy.status(now: now), .healthy)

        let expired = AgentKeyExpiry(validUntil: now.addingTimeInterval(-86_400), source: .onChain)
        XCTAssertEqual(expired.status(now: now), .expired)
    }
}
