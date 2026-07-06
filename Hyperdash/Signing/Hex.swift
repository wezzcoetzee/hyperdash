import Foundation
import CryptoSwift

enum Hex {
    static func decode(_ string: String) -> [UInt8]? {
        var s = string.lowercased()
        if s.hasPrefix("0x") { s = String(s.dropFirst(2)) }
        guard s.count % 2 == 0 else { return nil }
        var bytes = [UInt8]()
        bytes.reserveCapacity(s.count / 2)
        var index = s.startIndex
        while index < s.endIndex {
            let next = s.index(index, offsetBy: 2)
            guard let byte = UInt8(s[index..<next], radix: 16) else { return nil }
            bytes.append(byte)
            index = next
        }
        return bytes
    }

    static func encode(_ bytes: [UInt8], prefix: Bool = true) -> String {
        (prefix ? "0x" : "") + bytes.map { String(format: "%02x", $0) }.joined()
    }
}

enum Keccak {
    static func hash256(_ bytes: [UInt8]) -> [UInt8] {
        SHA3(variant: .keccak256).calculate(for: bytes)
    }
}
