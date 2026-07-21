import XCTest
@testable import Hyperdash

final class ExtraAgentTests: XCTestCase {

    func testExtraAgentsDecodeMsTimestamp() throws {
        let data = Data(Fixtures.extraAgents.utf8)
        let agents = try JSONDecoder().decode([ExtraAgent].self, from: data)
        XCTAssertEqual(agents.count, 2)
        XCTAssertEqual(agents.first?.validUntil, Date(timeIntervalSince1970: 4_102_444_800))
    }

    func testInfoServiceExtraAgents() async throws {
        let session = HyperliquidSession(network: .testnet, transport: FixtureTransport(infoFixtures: [
            "extraAgents": Fixtures.extraAgents
        ]))
        let agents = try await session.info.extraAgents(address: "0xabc")
        XCTAssertEqual(agents.count, 2)
    }
}
