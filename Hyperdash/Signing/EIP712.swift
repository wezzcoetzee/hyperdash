import Foundation

/// EIP-712 typed-data hashing, specialised to the "Agent" payload Hyperliquid
/// uses for L1 actions. The domain is fixed by the protocol:
/// `{ name: "Exchange", version: "1", chainId: 1337, verifyingContract: 0x0…0 }`.
enum EIP712 {
    private static let domainName = "Exchange"
    private static let domainVersion = "1"
    private static let chainId: UInt64 = 1337
    private static let verifyingContract = [UInt8](repeating: 0, count: 20)

    /// EIP-712 digest for `Agent(string source, bytes32 connectionId)`.
    static func agentDigest(source: String, connectionId: [UInt8]) -> [UInt8] {
        let separator = domainSeparator()
        let structHash = agentStructHash(source: source, connectionId: connectionId)
        var message: [UInt8] = [0x19, 0x01]
        message += separator
        message += structHash
        return Keccak.hash256(message)
    }

    private static func domainSeparator() -> [UInt8] {
        let typeHash = Keccak.hash256(Array(
            "EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)".utf8
        ))
        var encoded: [UInt8] = []
        encoded += typeHash
        encoded += Keccak.hash256(Array(domainName.utf8))
        encoded += Keccak.hash256(Array(domainVersion.utf8))
        encoded += uint256(chainId)
        encoded += leftPad32(verifyingContract)
        return Keccak.hash256(encoded)
    }

    private static func agentStructHash(source: String, connectionId: [UInt8]) -> [UInt8] {
        let typeHash = Keccak.hash256(Array("Agent(string source,bytes32 connectionId)".utf8))
        var encoded: [UInt8] = []
        encoded += typeHash
        encoded += Keccak.hash256(Array(source.utf8))
        encoded += leftPad32(connectionId)
        return Keccak.hash256(encoded)
    }

    private static func uint256(_ value: UInt64) -> [UInt8] {
        var bytes = [UInt8](repeating: 0, count: 32)
        withUnsafeBytes(of: value.bigEndian) { raw in
            for (i, byte) in raw.enumerated() { bytes[32 - raw.count + i] = byte }
        }
        return bytes
    }

    private static func leftPad32(_ bytes: [UInt8]) -> [UInt8] {
        precondition(bytes.count <= 32)
        return [UInt8](repeating: 0, count: 32 - bytes.count) + bytes
    }
}
