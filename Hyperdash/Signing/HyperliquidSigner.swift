import Foundation

/// Produces Hyperliquid L1-action signatures.
///
/// Scheme (mirrors the official Python SDK):
///   1. `connectionId = keccak256(msgpack(action) || nonce_be64 || vaultFlag[+addr])`
///   2. phantom agent = `{ source: "a"|"b", connectionId }`
///   3. sign the EIP-712 digest of that agent with the API-wallet key
///
/// ⚠️ Verify against **testnet** before mainnet. Msgpack field order and the
/// price/size wire encoding are the classic sources of "signature invalid" or
/// silently rejected orders.
struct HyperliquidSigner {
    struct Signature {
        let r: String
        let s: String
        let v: Int
    }

    let network: HyperliquidNetwork
    let privateKey: [UInt8]

    init(network: HyperliquidNetwork, privateKeyHex: String) throws {
        guard let key = Hex.decode(privateKeyHex), key.count == 32 else {
            throw Secp256k1Signer.SignerError.invalidPrivateKey
        }
        self.network = network
        self.privateKey = key
    }

    var agentAddress: String {
        (try? Hex.encode(Secp256k1Signer.address(privateKey: privateKey))) ?? "?"
    }

    func signL1Action(_ action: MsgPackValue, nonce: UInt64, vaultAddress: String?) throws -> Signature {
        let connectionId = Self.actionHash(action: action, nonce: nonce, vaultAddress: vaultAddress)
        let digest = EIP712.agentDigest(source: network.signatureSource, connectionId: connectionId)
        let sig = try Secp256k1Signer.sign(digest: digest, privateKey: privateKey)
        return Signature(r: Hex.encode(sig.r), s: Hex.encode(sig.s), v: sig.v)
    }

    static func actionHash(action: MsgPackValue, nonce: UInt64, vaultAddress: String?) -> [UInt8] {
        var data = action.encoded()
        data += withUnsafeBytes(of: nonce.bigEndian) { Array($0) }
        if let vault = vaultAddress, let bytes = Hex.decode(vault), bytes.count == 20 {
            data.append(0x01)
            data += bytes
        } else {
            data.append(0x00)
        }
        return Keccak.hash256(data)
    }
}
