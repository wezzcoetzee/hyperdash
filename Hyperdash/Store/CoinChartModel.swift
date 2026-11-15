import Foundation

/// A fetch that is waiting, done, or failed with something fit to show.
enum Loadable<Value> {
    case loading
    case loaded(Value)
    case failed(String)

    var value: Value? {
        if case .loaded(let value) = self { return value }
        return nil
    }
}

/// The candles behind one coin chart. Each `load` replaces them, so a view
/// drives it with `.task(id: request)` and a stale range is cancelled for free.
@MainActor
final class CoinChartModel: ObservableObject {
    struct Request: Hashable {
        let coin: String
        let range: CandleRange
        let network: HyperliquidNetwork
    }

    @Published private(set) var candles: Loadable<[Candle]> = .loading

    func load(_ request: Request, session: HyperliquidSession) async {
        candles = .loading
        do {
            let loaded = try await session.info.candles(coin: request.coin, range: request.range)
            if !Task.isCancelled { candles = .loaded(loaded) }
        } catch {
            if !Task.isCancelled { candles = .failed(error.userMessage) }
        }
    }
}
