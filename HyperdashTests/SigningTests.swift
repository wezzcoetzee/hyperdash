import XCTest
import libsecp256k1
@testable import Hyperdash

final class SigningTests: XCTestCase {

    private let keyHex = "0x0000000000000000000000000000000000000000000000000000000000000001"
    /// Well-known secp256k1 vector: private key 1.
    private let keyAddress = "0x7e5f4552091a69125d5dfcb7b8c2659029395bdf"

    // MARK: MessagePack

    func testMsgPackMapAndString() {
        let value = MsgPackValue.map([("type", .string("order"))])
        // 81 (map,1) a4 "type" a5 "order"
        let expected: [UInt8] = [0x81, 0xa4, 0x74, 0x79, 0x70, 0x65, 0xa5, 0x6f, 0x72, 0x64, 0x65, 0x72]
        XCTAssertEqual(value.encoded(), expected)
    }

    func testMsgPackBoolAndInt() {
        XCTAssertEqual(MsgPackValue.bool(true).encoded(), [0xc3])
        XCTAssertEqual(MsgPackValue.bool(false).encoded(), [0xc2])
        XCTAssertEqual(MsgPackValue.int(0).encoded(), [0x00])
        XCTAssertEqual(MsgPackValue.int(127).encoded(), [0x7f])
        XCTAssertEqual(MsgPackValue.int(-1).encoded(), [0xff])
        XCTAssertEqual(MsgPackValue.int(255).encoded(), [0xcc, 0xff])
        XCTAssertEqual(MsgPackValue.int(256).encoded(), [0xcd, 0x01, 0x00])
    }

    // MARK: Keys and signatures

    func testAgentKeyDerivesItsAddress() {
        XCTAssertEqual(AgentKeyIdentity.address(forKeyHex: keyHex), keyAddress)
        XCTAssertNil(AgentKeyIdentity.address(forKeyHex: "0xnothex"))
        XCTAssertNil(AgentKeyIdentity.address(forKeyHex: "0x01"))
    }

    /// Recovering the signer from an L1 signature must yield the agent's own
    /// address, which proves r, s and v are produced and encoded correctly.
    func testL1SignatureRecoversToTheAgentAddress() throws {
        let signer = try HyperliquidSigner(network: .testnet, privateKeyHex: keyHex)
        let action = TradeActions.cancelAction(assetId: 0, oid: 1)
        let nonce: UInt64 = 1_700_000_000_000

        let signature = try signer.signL1Action(action, nonce: nonce, vaultAddress: nil)

        let digest = EIP712.agentDigest(
            source: HyperliquidNetwork.testnet.signatureSource,
            connectionId: HyperliquidSigner.actionHash(action: action, nonce: nonce, vaultAddress: nil)
        )
        XCTAssertEqual(try recoveredAddress(digest: digest, signature: signature), keyAddress)
    }

    // MARK: Wire formatting

    func testWireStripsTrailingZeros() {
        XCTAssertEqual(Wire.size(1.2300, szDecimals: 4), "1.23")
        XCTAssertEqual(Wire.size(5, szDecimals: 2), "5")
    }

    private func recoveredAddress(digest: [UInt8], signature: HyperliquidSigner.Signature) throws -> String {
        let context = try XCTUnwrap(secp256k1_context_create(UInt32(SECP256K1_CONTEXT_NONE)))
        defer { secp256k1_context_destroy(context) }

        var compact = try XCTUnwrap(Hex.decode(signature.r)) + XCTUnwrap(Hex.decode(signature.s))
        var recoverable = secp256k1_ecdsa_recoverable_signature()
        XCTAssertEqual(secp256k1_ecdsa_recoverable_signature_parse_compact(
            context, &recoverable, &compact, Int32(signature.v - 27)), 1)

        var pubkey = secp256k1_pubkey()
        XCTAssertEqual(secp256k1_ecdsa_recover(context, &pubkey, &recoverable, digest), 1)

        var output = [UInt8](repeating: 0, count: 65)
        var length = 65
        secp256k1_ec_pubkey_serialize(context, &output, &length, &pubkey, UInt32(SECP256K1_EC_UNCOMPRESSED))
        return Hex.encode(Array(Keccak.hash256(Array(output[1...])).suffix(20)))
    }
}
