import Foundation

/// A perp market's headline numbers from `metaAndAssetCtxs`.
struct CoinStats: Equatable {
    let markPrice: Double
    /// Funding rate per hour as a fraction, so 0.0000125 is 0.00125%.
    let hourlyFunding: Double
    /// Open interest in the coin's own units.
    let openInterestCoins: Double
    let dayVolumeUSD: Double

    var openInterestUSD: Double { openInterestCoins * markPrice }
}

/// The `[meta, [ctx]]` response. A context belongs to the universe entry at
/// the same index, so lookup is by position, never by name.
struct MetaAndAssetCtxs: Decodable {
    private struct Meta: Decodable {
        let universe: [Asset]
        struct Asset: Decodable { let name: String }
    }

    struct Context: Decodable {
        let funding: String?
        let openInterest: String?
        let dayNtlVlm: String?
        let markPx: String?
    }

    private let coins: [String]
    let contexts: [Context]

    init(from decoder: Decoder) throws {
        var container = try decoder.unkeyedContainer()
        coins = try container.decode(Meta.self).universe.map(\.name)
        contexts = try container.decode([Context].self)
    }

    func stats(for coin: String) -> CoinStats? {
        guard let index = coins.firstIndex(of: coin), contexts.indices.contains(index) else { return nil }
        let context = contexts[index]
        return CoinStats(
            markPrice: (context.markPx ?? "").hlDouble,
            hourlyFunding: (context.funding ?? "").hlDouble,
            openInterestCoins: (context.openInterest ?? "").hlDouble,
            dayVolumeUSD: (context.dayNtlVlm ?? "").hlDouble
        )
    }
}
