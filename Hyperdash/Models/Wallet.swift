import Foundation

struct Wallet: Identifiable, Codable, Equatable, Hashable {
    let id: UUID
    var name: String
    var address: String

    init(id: UUID = UUID(), name: String, address: String) {
        self.id = id
        self.name = name
        self.address = Wallet.normalize(address)
    }

    /// Hyperliquid expects lowercased hex addresses when signing.
    static func normalize(_ address: String) -> String {
        address.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    static func isValidAddress(_ address: String) -> Bool {
        let a = normalize(address)
        guard a.hasPrefix("0x"), a.count == 42 else { return false }
        let hex = a.dropFirst(2)
        return hex.allSatisfy { $0.isHexDigit }
    }

    var shortAddress: String {
        guard address.count >= 10 else { return address }
        return "\(address.prefix(6))…\(address.suffix(4))"
    }
}
