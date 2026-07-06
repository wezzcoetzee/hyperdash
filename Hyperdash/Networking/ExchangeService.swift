import Foundation

/// Signs an action with the wallet's agent key and posts it to `/exchange`.
/// The envelope wire format — including the JSON mirror of the signed msgpack
/// bytes — is assembled here and nowhere else.
struct ExchangeService {
    let signer: HyperliquidSigner
    let client: HyperliquidClient

    init(network: HyperliquidNetwork, client: HyperliquidClient, agentKeyHex: String) throws {
        self.signer = try HyperliquidSigner(network: network, privateKeyHex: agentKeyHex)
        self.client = client
    }

    /// vaultAddress stays nil: an approved agent key signs directly for the
    /// account that authorised it.
    @discardableResult
    func submit(action: MsgPackValue, vaultAddress: String? = nil) async throws -> ExchangeResponse {
        let nonce = UInt64(Date().timeIntervalSince1970 * 1000)
        let signature = try signer.signL1Action(action, nonce: nonce, vaultAddress: vaultAddress)

        var envelope: [String: Any] = [
            "action": Self.json(action),
            "nonce": nonce,
            "signature": ["r": signature.r, "s": signature.s, "v": signature.v]
        ]
        if let vaultAddress { envelope["vaultAddress"] = vaultAddress }

        let response = try await client.exchange(envelope: envelope)
        if !response.isOK {
            throw HyperliquidError.exchange(response.errorMessage ?? "Exchange rejected the request.")
        }
        if let statusError = response.firstStatusError {
            throw HyperliquidError.exchange(statusError)
        }
        return response
    }

    /// JSON mirror of the msgpack structure so the signed bytes and posted
    /// JSON agree.
    private static func json(_ value: MsgPackValue) -> Any {
        switch value {
        case .string(let s): return s
        case .int(let i): return i
        case .uint(let u): return u
        case .bool(let b): return b
        case .double(let d): return d
        case .null: return NSNull()
        case .array(let items): return items.map { json($0) }
        case .map(let pairs):
            var dict = [String: Any]()
            for (k, v) in pairs { dict[k] = json(v) }
            return dict
        }
    }
}
