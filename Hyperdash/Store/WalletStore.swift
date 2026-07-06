import Foundation
import Combine

/// Owns the list of tracked wallets. Non-sensitive metadata (name, address)
/// is stored in UserDefaults and, when enabled, mirrored to iCloud key-value
/// storage. Agent private keys live only in the Keychain via `KeyStore`.
@MainActor
final class WalletStore: ObservableObject {
    @Published private(set) var wallets: [Wallet] = []

    private let defaults: UserDefaults
    private let ubiquitous = NSUbiquitousKeyValueStore.default
    private let storageKey = "wallets.v1"
    private var observer: NSObjectProtocol?

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        load()
        observer = NotificationCenter.default.addObserver(
            forName: NSUbiquitousKeyValueStore.didChangeExternallyNotification,
            object: ubiquitous,
            queue: .main
        ) { [weak self] _ in
            self?.reloadFromiCloud()
        }
        ubiquitous.synchronize()
    }

    func add(name: String, address: String, agentKeyHex: String?, synchronizable: Bool) throws {
        let wallet = Wallet(name: name, address: address)
        if let key = agentKeyHex, !key.isEmpty {
            try KeyStore.saveAgentKey(normalizeKey(key), for: wallet.id, synchronizable: synchronizable)
        }
        wallets.append(wallet)
        persist()
    }

    func update(_ wallet: Wallet) {
        guard let index = wallets.firstIndex(where: { $0.id == wallet.id }) else { return }
        wallets[index] = wallet
        persist()
    }

    func setAgentKey(_ keyHex: String?, for wallet: Wallet, synchronizable: Bool) throws {
        if let key = keyHex, !key.isEmpty {
            try KeyStore.saveAgentKey(normalizeKey(key), for: wallet.id, synchronizable: synchronizable)
        } else {
            try KeyStore.deleteAgentKey(for: wallet.id)
        }
        objectWillChange.send()
    }

    func remove(_ wallet: Wallet) {
        try? KeyStore.deleteAgentKey(for: wallet.id)
        wallets.removeAll { $0.id == wallet.id }
        persist()
    }

    func hasAgentKey(_ wallet: Wallet) -> Bool {
        KeyStore.hasAgentKey(for: wallet.id)
    }

    func agentKey(_ wallet: Wallet) -> String? {
        KeyStore.agentKey(for: wallet.id)
    }

    private func normalizeKey(_ hex: String) -> String {
        var k = hex.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if !k.hasPrefix("0x") { k = "0x" + k }
        return k
    }

    private func persist() {
        guard let data = try? JSONEncoder().encode(wallets) else { return }
        defaults.set(data, forKey: storageKey)
        ubiquitous.set(data, forKey: storageKey)
    }

    private func load() {
        if let data = ubiquitous.data(forKey: storageKey) ?? defaults.data(forKey: storageKey),
           let decoded = try? JSONDecoder().decode([Wallet].self, from: data) {
            wallets = decoded
        }
    }

    private func reloadFromiCloud() {
        if let data = ubiquitous.data(forKey: storageKey),
           let decoded = try? JSONDecoder().decode([Wallet].self, from: data) {
            wallets = decoded
            defaults.set(data, forKey: storageKey)
        }
    }
}
