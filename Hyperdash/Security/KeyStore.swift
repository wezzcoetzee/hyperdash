import Foundation
import Security

/// Stores agent (API) wallet private keys in the Keychain.
///
/// Keys are the app's most sensitive material: they can place and cancel trades
/// (but by Hyperliquid's design cannot withdraw funds). When iCloud sync is on,
/// items are written with `kSecAttrSynchronizable` so they roam via iCloud
/// Keychain, encrypted end-to-end by Apple.
enum KeyStore {
    private static let service = "com.wcoetzee.hyperdash.agentkey"

    enum KeyStoreError: LocalizedError {
        case unexpectedStatus(OSStatus)
        var errorDescription: String? {
            switch self {
            case .unexpectedStatus(let status):
                let message = SecCopyErrorMessageString(status, nil) as String? ?? "\(status)"
                return "Keychain error: \(message)"
            }
        }
    }

    static func saveAgentKey(_ privateKeyHex: String, for walletID: UUID, synchronizable: Bool) throws {
        let account = walletID.uuidString
        guard let data = privateKeyHex.data(using: .utf8) else { return }

        try? deleteAgentKey(for: walletID)

        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]
        if synchronizable {
            query[kSecAttrSynchronizable as String] = kCFBooleanTrue!
            query[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlocked
        }

        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else { throw KeyStoreError.unexpectedStatus(status) }
    }

    static func agentKey(for walletID: UUID) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: walletID.uuidString,
            kSecAttrSynchronizable as String: kSecAttrSynchronizableAny,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status == errSecSuccess,
              let data = item as? Data,
              let hex = String(data: data, encoding: .utf8) else {
            return nil
        }
        return hex
    }

    static func hasAgentKey(for walletID: UUID) -> Bool {
        agentKey(for: walletID) != nil
    }

    static func deleteAgentKey(for walletID: UUID) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: walletID.uuidString,
            kSecAttrSynchronizable as String: kSecAttrSynchronizableAny
        ]
        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeyStoreError.unexpectedStatus(status)
        }
    }
}
