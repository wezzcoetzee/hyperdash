import XCTest
@testable import Hyperdash

@MainActor
final class AgentKeyExpiryStoreTests: XCTestCase {
    private let address = "0x7e5f4552091a69125d5dfcb7b8c2659029395bdf"
    private let key = "0x0000000000000000000000000000000000000000000000000000000000000001"

    private func session(agentValidUntilMs: Int64) -> HyperliquidSession {
        let fixture = #"[{"name":"hyperdash","address":"\#(address)","validUntil":\#(agentValidUntilMs)}]"#
        return HyperliquidSession(network: .testnet, transport: FixtureTransport(infoFixtures: [
            "extraAgents": fixture
        ]))
    }

    func testRefreshPopulatesExpiryForWalletWithKey() async {
        let wallet = Wallet(name: "Main", address: address, keyAddedAt: Date())
        let store = AgentKeyExpiryStore()
        await store.refresh(wallets: [wallet], session: session(agentValidUntilMs: 4_102_444_800_000)) { _ in
            self.key
        }
        XCTAssertEqual(store.expiries[wallet.id]?.source, .onChain)
    }

    func testWalletWithoutKeyOmitted() async {
        let wallet = Wallet(name: "Main", address: address)
        let store = AgentKeyExpiryStore()
        await store.refresh(wallets: [wallet], session: session(agentValidUntilMs: 4_102_444_800_000)) { _ in nil }
        XCTAssertNil(store.expiries[wallet.id])
    }

    func testExpiringSoonFilter() async {
        let wallet = Wallet(name: "Main", address: address, keyAddedAt: Date())
        let store = AgentKeyExpiryStore()
        await store.refresh(wallets: [wallet], session: session(agentValidUntilMs: 1_000_000_000_000)) { _ in
            self.key
        }
        XCTAssertNotNil(store.expiringSoon[wallet.id])
    }
}
