import Foundation

/// Bridges a stored agent private key to its on-chain agent address so expiry
/// records can be matched against `extraAgents`. Malformed keys resolve to nil
/// rather than surfacing errors into UI code.
enum AgentKeyIdentity {
    static func address(forKeyHex hex: String) -> String? {
        guard let bytes = Hex.decode(hex), bytes.count == 32,
              let addr = try? Secp256k1Signer.address(privateKey: bytes) else { return nil }
        return Hex.encode(addr)
    }
}
