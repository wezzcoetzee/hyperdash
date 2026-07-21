import XCTest
@testable import Hyperdash

final class AgentKeyExpiryResolverTests: XCTestCase {

    private func agents() throws -> [ExtraAgent] {
        try JSONDecoder().decode([ExtraAgent].self, from: Data(Fixtures.extraAgents.utf8))
    }

    private let aaAddress = "0x00000000000000000000000000000000000000aa"

    func testMatchesOnChainByAddress() throws {
        let expiry = AgentKeyExpiryResolver.resolve(agentAddress: aaAddress, agents: try agents(), keyAddedAt: nil)
        XCTAssertEqual(expiry?.source, .onChain)
        XCTAssertEqual(expiry?.validUntil, Date(timeIntervalSince1970: 4_102_444_800))
    }

    func testAddressMatchIsCaseInsensitive() throws {
        let expiry = AgentKeyExpiryResolver.resolve(agentAddress: aaAddress.uppercased(),
                                                    agents: try agents(), keyAddedAt: nil)
        XCTAssertEqual(expiry?.source, .onChain)
    }

    func testFallsBackToEstimatedWhenNotFound() throws {
        let added = Date(timeIntervalSince1970: 1_000_000)
        let expiry = AgentKeyExpiryResolver.resolve(agentAddress: "0xdeadbeef",
                                                    agents: try agents(), keyAddedAt: added)
        XCTAssertEqual(expiry?.source, .estimated)
        XCTAssertEqual(expiry?.validUntil, added.addingTimeInterval(AgentKeyExpiry.agentKeyLifetime))
    }

    func testReturnsNilWithNoKeyInfo() throws {
        let expiry = AgentKeyExpiryResolver.resolve(agentAddress: nil, agents: try agents(), keyAddedAt: nil)
        XCTAssertNil(expiry)
    }
}
