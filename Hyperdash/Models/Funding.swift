import Foundation

/// One hourly funding payment from the `userFunding` info request. `usdc` is
/// signed from the wallet's side: negative means it paid, positive means it received.
struct FundingPayment: Decodable, Equatable {
    let time: Date
    let coin: String
    let usdc: Double

    private enum CodingKeys: String, CodingKey { case time, delta }
    private enum DeltaKeys: String, CodingKey { case coin, usdc }

    init(time: Date, coin: String, usdc: Double) {
        self.time = time
        self.coin = coin
        self.usdc = usdc
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        time = Date(timeIntervalSince1970: try c.decode(Double.self, forKey: .time) / 1000)
        let delta = try c.nestedContainer(keyedBy: DeltaKeys.self, forKey: .delta)
        coin = try delta.decode(String.self, forKey: .coin)
        usdc = try delta.decode(String.self, forKey: .usdc).hlDouble
    }
}

struct FundingSummary: Equatable {
    struct CoinTotal: Equatable {
        let coin: String
        let net: Double
    }

    static let topCoinCount = 5
    static let otherLabel = "Other"

    let net24h: Double
    let net7d: Double
    /// Largest by magnitude first; coins past the top five fold into one "Other" row.
    let byCoin: [CoinTotal]

    /// Nil when there is no funding history at all, so the UI can hide itself.
    init?(payments: [FundingPayment], now: Date = Date()) {
        guard !payments.isEmpty else { return nil }
        let dayAgo = now.addingTimeInterval(-24 * 3600)
        net24h = payments.filter { $0.time >= dayAgo }.reduce(0) { $0 + $1.usdc }
        net7d = payments.reduce(0) { $0 + $1.usdc }

        let totals = Dictionary(grouping: payments, by: \.coin)
            .map { CoinTotal(coin: $0.key, net: $0.value.reduce(0) { $0 + $1.usdc }) }
            .sorted { abs($0.net) != abs($1.net) ? abs($0.net) > abs($1.net) : $0.coin < $1.coin }
        let rest = totals.dropFirst(Self.topCoinCount)
        byCoin = Array(totals.prefix(Self.topCoinCount))
            + (rest.isEmpty ? [] : [CoinTotal(coin: Self.otherLabel, net: rest.reduce(0) { $0 + $1.net })])
    }
}
