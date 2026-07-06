import Foundation

/// Releases a wallet's signing key only after the owner authenticates.
/// The biometric-gate-before-Keychain ordering is enforced here, not
/// remembered by callers.
protocol Vault: Sendable {
    func signingKey(for wallet: Wallet, reason: String) async throws -> String
}

enum VaultError: LocalizedError {
    case authenticationCancelled
    case missingKey

    var errorDescription: String? {
        switch self {
        case .authenticationCancelled:
            return "Authentication cancelled."
        case .missingKey:
            return "No agent key stored for this wallet."
        }
    }
}

struct DeviceVault: Vault {
    func signingKey(for wallet: Wallet, reason: String) async throws -> String {
        guard await BiometricAuth.authenticate(reason: reason) else {
            throw VaultError.authenticationCancelled
        }
        guard let key = KeyStore.agentKey(for: wallet.id) else {
            throw VaultError.missingKey
        }
        return key
    }
}
