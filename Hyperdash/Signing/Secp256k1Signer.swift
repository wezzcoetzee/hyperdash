import Foundation
import libsecp256k1

/// Low-level secp256k1 operations over the C library vendored by
/// `21-DOT-DEV/swift-secp256k1` (product `libsecp256k1`). Signs a *pre-hashed*
/// 32-byte message (an EIP-712 digest) and produces an Ethereum-style
/// recoverable signature.
enum Secp256k1Signer {
    struct RecoverableSignature {
        let r: [UInt8]   // 32 bytes
        let s: [UInt8]   // 32 bytes
        let v: Int       // 27 or 28
    }

    enum SignerError: LocalizedError {
        case invalidPrivateKey
        case invalidDigest
        case signingFailed
        case pubkeyFailed
        var errorDescription: String? {
            switch self {
            case .invalidPrivateKey: return "Invalid agent private key."
            case .invalidDigest: return "Invalid message digest."
            case .signingFailed: return "secp256k1 signing failed."
            case .pubkeyFailed: return "Could not derive public key."
            }
        }
    }

    private static let context: OpaquePointer = {
        secp256k1_context_create(UInt32(SECP256K1_CONTEXT_NONE))!
    }()

    static func sign(digest: [UInt8], privateKey: [UInt8]) throws -> RecoverableSignature {
        guard privateKey.count == 32 else { throw SignerError.invalidPrivateKey }
        guard digest.count == 32 else { throw SignerError.invalidDigest }

        var recoverable = secp256k1_ecdsa_recoverable_signature()
        let ok = secp256k1_ecdsa_sign_recoverable(context, &recoverable, digest, privateKey, nil, nil)
        guard ok == 1 else { throw SignerError.signingFailed }

        var output = [UInt8](repeating: 0, count: 64)
        var recid: Int32 = 0
        secp256k1_ecdsa_recoverable_signature_serialize_compact(context, &output, &recid, &recoverable)

        return RecoverableSignature(
            r: Array(output[0..<32]),
            s: Array(output[32..<64]),
            v: Int(recid) + 27
        )
    }

    /// Uncompressed public key (65 bytes, 0x04-prefixed).
    static func publicKey(privateKey: [UInt8]) throws -> [UInt8] {
        guard privateKey.count == 32 else { throw SignerError.invalidPrivateKey }
        var pubkey = secp256k1_pubkey()
        guard secp256k1_ec_pubkey_create(context, &pubkey, privateKey) == 1 else {
            throw SignerError.pubkeyFailed
        }
        var output = [UInt8](repeating: 0, count: 65)
        var length = 65
        secp256k1_ec_pubkey_serialize(context, &output, &length, &pubkey, UInt32(SECP256K1_EC_UNCOMPRESSED))
        return output
    }

    /// Ethereum address (20 bytes) derived from a private key.
    static func address(privateKey: [UInt8]) throws -> [UInt8] {
        let pub = try publicKey(privateKey: privateKey)
        let hash = Keccak.hash256(Array(pub[1..<65]))
        return Array(hash.suffix(20))
    }

    /// Recovers the signer address from a digest + recoverable signature.
    /// Used by tests to prove the signing pipeline round-trips.
    static func recoverAddress(digest: [UInt8], signature: RecoverableSignature) throws -> [UInt8] {
        var compact = signature.r + signature.s
        var recoverable = secp256k1_ecdsa_recoverable_signature()
        let recid = Int32(signature.v - 27)
        guard secp256k1_ecdsa_recoverable_signature_parse_compact(context, &recoverable, &compact, recid) == 1 else {
            throw SignerError.signingFailed
        }
        var pubkey = secp256k1_pubkey()
        guard secp256k1_ecdsa_recover(context, &pubkey, &recoverable, digest) == 1 else {
            throw SignerError.pubkeyFailed
        }
        var output = [UInt8](repeating: 0, count: 65)
        var length = 65
        secp256k1_ec_pubkey_serialize(context, &output, &length, &pubkey, UInt32(SECP256K1_EC_UNCOMPRESSED))
        let hash = Keccak.hash256(Array(output[1..<65]))
        return Array(hash.suffix(20))
    }
}
