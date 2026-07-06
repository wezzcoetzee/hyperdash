import Foundation

enum HyperliquidNetwork: String, Codable, CaseIterable, Identifiable {
    case mainnet
    case testnet

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .mainnet: return "Mainnet"
        case .testnet: return "Testnet"
        }
    }

    var apiBaseURL: URL {
        switch self {
        case .mainnet: return URL(string: "https://api.hyperliquid.xyz")!
        case .testnet: return URL(string: "https://api.hyperliquid-testnet.xyz")!
        }
    }

    /// Source byte used in the phantom-agent EIP-712 payload for L1 actions.
    var signatureSource: String {
        switch self {
        case .mainnet: return "a"
        case .testnet: return "b"
        }
    }
}
