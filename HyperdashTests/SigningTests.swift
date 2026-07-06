import XCTest
@testable import Hyperdash

final class SigningTests: XCTestCase {

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

    // MARK: secp256k1 / address derivation

    /// Well-known secp256k1 vector: private key 1 → 0x7e5f4552091a69125d5dfcb7b8c2659029395bdf
    func testAddressFromPrivateKeyVector() throws {
        let key = Hex.decode("0x0000000000000000000000000000000000000000000000000000000000000001")!
        let address = try Secp256k1Signer.address(privateKey: key)
        XCTAssertEqual(Hex.encode(address), "0x7e5f4552091a69125d5dfcb7b8c2659029395bdf")
    }

    /// Signing then recovering must return the signer's own address. This proves
    /// the secp256k1 + keccak recoverable-signature pipeline end to end.
    func testSignRecoverRoundTrip() throws {
        let key = Hex.decode("0x0000000000000000000000000000000000000000000000000000000000000001")!
        let digest = Keccak.hash256(Array("hyperdash".utf8))
        let signature = try Secp256k1Signer.sign(digest: digest, privateKey: key)
        XCTAssertTrue(signature.v == 27 || signature.v == 28)

        let recovered = try Secp256k1Signer.recoverAddress(digest: digest, signature: signature)
        let expected = try Secp256k1Signer.address(privateKey: key)
        XCTAssertEqual(recovered, expected)
    }

    // MARK: Action hash determinism

    func testActionHashIsDeterministic() {
        let action = TradeActions.cancelAction(assetId: 0, oid: 123)
        let a = HyperliquidSigner.actionHash(action: action, nonce: 1, vaultAddress: nil)
        let b = HyperliquidSigner.actionHash(action: action, nonce: 1, vaultAddress: nil)
        XCTAssertEqual(a, b)
        XCTAssertEqual(a.count, 32)

        let differentNonce = HyperliquidSigner.actionHash(action: action, nonce: 2, vaultAddress: nil)
        XCTAssertNotEqual(a, differentNonce)
    }

    func testFullSignatureShape() throws {
        let signer = try HyperliquidSigner(
            network: .testnet,
            privateKeyHex: "0x0000000000000000000000000000000000000000000000000000000000000001"
        )
        let action = TradeActions.cancelAction(assetId: 0, oid: 1)
        let signature = try signer.signL1Action(action, nonce: 1_700_000_000_000, vaultAddress: nil)
        XCTAssertTrue(signature.r.hasPrefix("0x"))
        XCTAssertEqual(signature.r.count, 66)
        XCTAssertEqual(signature.s.count, 66)
    }

    // MARK: Wire formatting

    func testWireStripsTrailingZeros() {
        XCTAssertEqual(Wire.size(1.2300, szDecimals: 4), "1.23")
        XCTAssertEqual(Wire.size(5, szDecimals: 2), "5")
    }
}
