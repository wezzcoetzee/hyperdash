import Foundation

enum Loadable<Value> {
    case loading
    case loaded(Value)
    case failed

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
        /// Bumped by a retry so it restarts the load as a new `.task(id:)`.
        var attempt = 0
    }

    @Published private(set) var candles: Loadable<[Candle]> = .loading

    /// `keepingPrevious` leaves the last candles up while the next range loads,
    /// for a chart that sits behind something and shouldn't blink.
    func load(_ request: Request, session: HyperliquidSession, keepingPrevious: Bool = false) async {
        if !(keepingPrevious && candles.value != nil) { candles = .loading }
        do {
            let loaded = try await session.info.candles(coin: request.coin, range: request.range)
            if !Task.isCancelled { candles = .loaded(loaded) }
        } catch {
            if !Task.isCancelled { candles = .failed }
        }
    }
}
