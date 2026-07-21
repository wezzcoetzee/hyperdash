import Foundation
import Combine

/// Resolves agent-key expiry once per wallet so list rows and the dashboard
/// warning section share the same data. Key access is injected so tests can
/// avoid the Keychain.
@MainActor
final class AgentKeyExpiryStore: ObservableObject {
    @Published private(set) var expiries: [UUID: AgentKeyExpiry] = [:]

    func refresh(wallets: [Wallet],
                 session: HyperliquidSession,
                 keyProvider: (Wallet) -> String?) async {
        var next: [UUID: AgentKeyExpiry] = [:]
        await withTaskGroup(of: (UUID, AgentKeyExpiry?).self) { group in
            for wallet in wallets {
                guard let keyHex = keyProvider(wallet) else { continue }
                let derived = AgentKeyIdentity.address(forKeyHex: keyHex)
                let added = wallet.keyAddedAt
                let addr = wallet.address
                let id = wallet.id
                group.addTask {
                    let agents = (try? await session.info.extraAgents(address: addr)) ?? []
                    return (id, AgentKeyExpiryResolver.resolve(
                        agentAddress: derived, agents: agents, keyAddedAt: added))
                }
            }
            for await (id, expiry) in group { if let expiry { next[id] = expiry } }
        }
        expiries = next
    }

    var expiringSoon: [UUID: AgentKeyExpiry] {
        expiries.filter { $0.value.status() != .healthy }
    }
}
