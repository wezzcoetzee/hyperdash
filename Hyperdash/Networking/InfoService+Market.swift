import Foundation

/// Public market data behind the coin charts. Core-DEX coins only: builder
/// DEX markets name their coins differently and need a `dex` on every request.
extension InfoService {
    func candles(coin: String, range: CandleRange, now: Date = Date()) async throws -> [Candle] {
        try await client.info(range.request(coin: coin, now: now), as: [Candle].self)
    }

    /// `nil` when the coin isn't in the core universe.
    func coinStats(coin: String) async throws -> CoinStats? {
        try await client.info(["type": "metaAndAssetCtxs"], as: MetaAndAssetCtxs.self).stats(for: coin)
    }
}
