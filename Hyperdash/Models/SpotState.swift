import Foundation

/// Response of the `spotClearinghouseState` info request.
struct SpotState: Decodable {
    let balances: [SpotBalance]

    var nonZeroBalances: [SpotBalance] {
        balances.filter { $0.totalValue > 0 }
    }
}

struct SpotBalance: Decodable, Identifiable {
    let coin: String
    let token: Int
    let total: String
    let hold: String
    let entryNtl: String?

    var id: String { "\(token)-\(coin)" }
    var totalValue: Double { total.hlDouble }
    var holdValue: Double { hold.hlDouble }
    var availableValue: Double { totalValue - holdValue }
    var entryNotional: Double? { entryNtl?.hlDouble }
    var isUSDC: Bool { coin.uppercased() == "USDC" }
}
