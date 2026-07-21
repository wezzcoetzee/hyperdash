import Foundation
import Combine

/// Owns the list of tracked wallets. Non-sensitive metadata (name, address)
/// is stored in UserDefaults and, when enabled, mirrored to iCloud key-value
/// storage. Agent private keys live only in the Keychain via `KeyStore`.
@MainActor
final class WalletStore: ObservableObject {
    @Published private(set) var wallets: [Wallet] = []

    private let defaults: UserDefaults
    private let ubiquitous: UbiquitousKeyValueStoring
    private let storageKey = "wallets.v1"
    private var iCloudSyncEnabled: Bool
    private var observer: NSObjectProtocol?

    init(
        defaults: UserDefaults = .standard,
        ubiquitous: UbiquitousKeyValueStoring = NSUbiquitousKeyValueStore.default,
        iCloudSyncEnabled: Bool = false,
        observeExternalChanges: Bool = true
    ) {
        self.defaults = defaults
        self.ubiquitous = ubiquitous
        self.iCloudSyncEnabled = iCloudSyncEnabled
        load()
        if observeExternalChanges {
            let notificationObject = ubiquitous as? NSUbiquitousKeyValueStore
            observer = NotificationCenter.default.addObserver(
                forName: NSUbiquitousKeyValueStore.didChangeExternallyNotification,
                object: notificationObject,
                queue: .main
            ) { [weak self] _ in
                Task { @MainActor in
                    self?.handleExternaliCloudChange()
                }
            }
        }
        if iCloudSyncEnabled {
            ubiquitous.synchronize()
        }
    }

    func add(name: String, address: String, agentKeyHex: String?, synchronizable: Bool) throws {
        let hasKey = agentKeyHex.map { !$0.isEmpty } ?? false
        let wallet = Wallet(name: name, address: address, keyAddedAt: hasKey ? Date() : nil)
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
        let hasKey = keyHex.map { !$0.isEmpty } ?? false
        if let key = keyHex, !key.isEmpty {
            try KeyStore.saveAgentKey(normalizeKey(key), for: wallet.id, synchronizable: synchronizable)
        } else {
            try KeyStore.deleteAgentKey(for: wallet.id)
        }
        if let index = wallets.firstIndex(where: { $0.id == wallet.id }) {
            wallets[index].keyAddedAt = hasKey ? Date() : nil
        }
        persist()
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

    func setiCloudSyncEnabled(_ enabled: Bool, migrateKeys: Bool = true) {
        guard enabled != iCloudSyncEnabled else { return }
        iCloudSyncEnabled = enabled

        if migrateKeys {
            migrateAgentKeys(synchronizable: enabled)
        }

        if enabled {
            persist()
            ubiquitous.synchronize()
        } else {
            if let data = encodedWallets() {
                defaults.set(data, forKey: storageKey)
            }
            ubiquitous.removeObject(forKey: storageKey)
            ubiquitous.synchronize()
        }
    }

    private func normalizeKey(_ hex: String) -> String {
        var k = hex.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if !k.hasPrefix("0x") { k = "0x" + k }
        return k
    }

    private func persist() {
        guard let data = encodedWallets() else { return }
        defaults.set(data, forKey: storageKey)
        if iCloudSyncEnabled {
            ubiquitous.set(data, forKey: storageKey)
        }
    }

    private func load() {
        let cloudData = iCloudSyncEnabled ? ubiquitous.data(forKey: storageKey) : nil
        if let data = cloudData ?? defaults.data(forKey: storageKey),
           let decoded = try? JSONDecoder().decode([Wallet].self, from: data) {
            wallets = decoded
        }
    }

    func handleExternaliCloudChange() {
        guard iCloudSyncEnabled else { return }
        if let data = ubiquitous.data(forKey: storageKey),
           let decoded = try? JSONDecoder().decode([Wallet].self, from: data) {
            wallets = decoded
            defaults.set(data, forKey: storageKey)
        }
    }

    private func encodedWallets() -> Data? {
        try? JSONEncoder().encode(wallets)
    }

    private func migrateAgentKeys(synchronizable: Bool) {
        for wallet in wallets {
            guard let key = KeyStore.agentKey(for: wallet.id) else { continue }
            try? KeyStore.saveAgentKey(key, for: wallet.id, synchronizable: synchronizable)
        }
    }
}
