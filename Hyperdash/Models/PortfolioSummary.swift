import Foundation

/// Every wallet folded into one glanceable figure: total value, 24h change and
/// the combined value over the day. Compiled into the widget extension too.
struct PortfolioSummary: Equatable {
    let value: Double
    let dayChange: DayChange?
    /// Combined account value over the portfolio `day` window, oldest first.
    let dayHistory: [PortfolioPoint]

    /// `value` per wallet is its account balance; the day change is weighted
    /// across the wallets that have enough history to measure one.
    init(_ wallets: [(value: Double, portfolio: PortfolioResponse)]) {
        value = wallets.reduce(0) { $0 + $1.value }
        dayChange = DayChange.combined(wallets.compactMap {
            DayChange(dayPnl: $0.portfolio.pnlSeries(.day), value: $0.value)
        })
        dayHistory = PortfolioAggregator.sum(wallets.map { $0.portfolio.accountValueSeries(.day) })
    }
}
