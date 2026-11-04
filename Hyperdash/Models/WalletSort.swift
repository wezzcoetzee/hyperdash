import Foundation

/// How the wallets tab orders its rows. Purely a view of the list: the stored
/// custom order is never rewritten by picking another sort.
enum WalletSort: String, CaseIterable, Identifiable {
    case custom, value, dayChange, openPnl

    var id: String { rawValue }

    var label: String {
        switch self {
        case .custom: "Custom"
        case .value: "Value"
        case .dayChange: "24h Change"
        case .openPnl: "Open PnL"
        }
    }

    /// Highest first. Wallets without a figure yet sink to the bottom, and ties
    /// keep their custom order so the list doesn't shuffle between refreshes.
    func sorted(_ wallets: [Wallet], data: [UUID: WalletData]) -> [Wallet] {
        guard self != .custom else { return wallets }
        return wallets.enumerated()
            .map { (index: $0.offset, wallet: $0.element, key: data[$0.element.id].flatMap(key)) }
            .sorted { a, b in
                switch (a.key, b.key) {
                case let (l?, r?) where l != r: return l > r
                case (.some, nil): return true
                case (nil, .some): return false
                default: return a.index < b.index
                }
            }
            .map(\.wallet)
    }

    private func key(_ data: WalletData) -> Double? {
        switch self {
        case .custom: nil
        case .value: data.value
        case .dayChange: data.dayChange?.percent
        case .openPnl: data.snapshot.totalUnrealizedPnl
        }
    }
}
