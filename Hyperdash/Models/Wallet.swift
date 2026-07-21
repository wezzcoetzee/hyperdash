import Foundation

enum WalletIcon: String, CaseIterable, Codable, Identifiable {
    case wallet = "wallet.bifold.fill"
    case personal = "person.crop.circle.fill"
    case trading = "chart.line.uptrend.xyaxis"
    case savings = "banknote.fill"
    case vault = "lock.shield.fill"
    case business = "briefcase.fill"
    case bot = "cpu.fill"
    case test = "flask.fill"

    var id: String { rawValue }

    var label: String {
        switch self {
        case .wallet: "Wallet"
        case .personal: "Personal"
        case .trading: "Trading"
        case .savings: "Savings"
        case .vault: "Vault"
        case .business: "Business"
        case .bot: "Bot"
        case .test: "Test"
        }
    }
}

struct Wallet: Identifiable, Codable, Equatable, Hashable {
    let id: UUID
    var name: String
    var address: String
    var icon: WalletIcon
    var keyAddedAt: Date?

    init(
        id: UUID = UUID(),
        name: String,
        address: String,
        icon: WalletIcon = .wallet,
        keyAddedAt: Date? = nil
    ) {
        self.id = id
        self.name = name
        self.address = Wallet.normalize(address)
        self.icon = icon
        self.keyAddedAt = keyAddedAt
    }

    private enum CodingKeys: String, CodingKey {
        case id, name, address, icon, keyAddedAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        address = Wallet.normalize(try container.decode(String.self, forKey: .address))
        icon = try container.decodeIfPresent(WalletIcon.self, forKey: .icon) ?? .wallet
        keyAddedAt = try container.decodeIfPresent(Date.self, forKey: .keyAddedAt)
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
