import XCTest
@testable import Hyperdash

final class AgentKeyIdentityTests: XCTestCase {

    private let keyHex = "0x0000000000000000000000000000000000000000000000000000000000000001"

    func testDerivesAddressFromKnownKey() throws {
        let expected = Hex.encode(try Secp256k1Signer.address(privateKey: Hex.decode(keyHex)!))
        XCTAssertEqual(AgentKeyIdentity.address(forKeyHex: keyHex), expected)
        XCTAssertEqual(AgentKeyIdentity.address(forKeyHex: keyHex),
                       "0x7e5f4552091a69125d5dfcb7b8c2659029395bdf")
    }

    func testMalformedKeyReturnsNil() {
        XCTAssertNil(AgentKeyIdentity.address(forKeyHex: "0xnothex"))
        XCTAssertNil(AgentKeyIdentity.address(forKeyHex: "0x01"))
    }
}
