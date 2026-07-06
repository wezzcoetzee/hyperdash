import Foundation

/// Resolves a coin symbol to the wire fields an order needs: the numeric asset
/// id, size decimals, and the `allMids` key for a reference price.
///
/// Perp asset id = index into `meta.universe`.
/// Spot asset id = 10000 + index into `spotMeta.universe`.
struct AssetInfo {
    let assetId: Int
    let szDecimals: Int
    let isSpot: Bool
    let midKey: String
}

actor MetaService {
    private let client: HyperliquidClient
    private var perp: PerpMeta?
    private var spot: SpotMeta?

    init(client: HyperliquidClient) {
        self.client = client
    }

    struct PerpMeta: Decodable { let universe: [Asset]; struct Asset: Decodable { let name: String; let szDecimals: Int } }
    struct SpotMeta: Decodable {
        let tokens: [Token]
        let universe: [Pair]
        struct Token: Decodable { let name: String; let szDecimals: Int; let index: Int }
        struct Pair: Decodable { let name: String; let tokens: [Int]; let index: Int }
    }

    private func perpMeta() async throws -> PerpMeta {
        if let perp { return perp }
        let meta = try await client.info(["type": "meta"], as: PerpMeta.self)
        perp = meta
        return meta
    }

    private func spotMeta() async throws -> SpotMeta {
        if let spot { return spot }
        let meta = try await client.info(["type": "spotMeta"], as: SpotMeta.self)
        spot = meta
        return meta
    }

    func perpAsset(coin: String) async throws -> AssetInfo {
        let meta = try await perpMeta()
        guard let index = meta.universe.firstIndex(where: { $0.name == coin }) else {
            throw HyperliquidError.exchange("Unknown perp asset \(coin)")
        }
        return AssetInfo(assetId: index, szDecimals: meta.universe[index].szDecimals, isSpot: false, midKey: coin)
    }

    /// Resolves the asset id for an existing open order's `coin` field, which
    /// may be a perp name ("BTC"), a spot pair name ("PURR/USDC"), or "@<index>".
    func orderAssetId(coin: String) async throws -> Int {
        if coin.hasPrefix("@"), let index = Int(coin.dropFirst()) {
            return 10000 + index
        }
        if coin.contains("/") {
            let meta = try await spotMeta()
            if let pair = meta.universe.first(where: { $0.name == coin }) {
                return 10000 + pair.index
            }
        }
        let meta = try await perpMeta()
        if let index = meta.universe.firstIndex(where: { $0.name == coin }) {
            return index
        }
        throw HyperliquidError.exchange("Unknown order asset \(coin)")
    }

    /// Resolves the "<coin>/USDC" spot pair for selling `coin` into USDC.
    func spotAssetToUSDC(coin: String) async throws -> AssetInfo {
        guard let (pair, token) = try await usdcPair(for: coin) else {
            throw HyperliquidError.exchange("No \(coin)/USDC spot market")
        }
        return AssetInfo(assetId: 10000 + pair.index, szDecimals: token.szDecimals, isSpot: true, midKey: "@\(pair.index)")
    }

    /// The `allMids` key carrying `coin`'s USDC price, or nil when the coin has
    /// no USDC market.
    func spotMidKey(coin: String) async throws -> String? {
        guard let (pair, _) = try await usdcPair(for: coin) else { return nil }
        return "@\(pair.index)"
    }

    private func usdcPair(for coin: String) async throws -> (pair: SpotMeta.Pair, token: SpotMeta.Token)? {
        let meta = try await spotMeta()
        guard let token = meta.tokens.first(where: { $0.name == coin }) else { return nil }
        let usdcIndex = meta.tokens.first(where: { $0.name == "USDC" })?.index ?? 0
        guard let pair = meta.universe.first(where: { $0.tokens.count == 2 && $0.tokens[0] == token.index && $0.tokens[1] == usdcIndex }) else {
            return nil
        }
        return (pair, token)
    }
}
