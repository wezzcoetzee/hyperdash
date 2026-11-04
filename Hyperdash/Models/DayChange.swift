import Foundation

/// A wallet's (or several wallets') move over the last 24 hours.
///
/// The dollar change comes from the portfolio's `day` PnL history rather than
/// its account value history, so deposits and withdrawals never read as gains
/// or losses.
struct DayChange: Equatable {
    let amount: Double
    /// Value now, which the percentage is measured back from.
    let value: Double

    /// Change relative to the value 24h ago, in percent. Nil when that base is
    /// zero or negative, where a percentage would mean nothing.
    var percent: Double? {
        let base = value - amount
        return base > 0 ? amount / base * 100 : nil
    }

    var isPositive: Bool { amount >= 0 }

    init(amount: Double, value: Double) {
        self.amount = amount
        self.value = value
    }

    /// Nil when the window has fewer than two points to measure between.
    init?(dayPnl history: [PortfolioPoint], value: Double) {
        guard history.count >= 2,
              let first = history.min(by: { $0.date < $1.date }),
              let last = history.max(by: { $0.date < $1.date }) else { return nil }
        self.init(amount: last.value - first.value, value: value)
    }

    /// Sums changes so the combined percentage is weighted by value, not averaged.
    static func combined(_ changes: [DayChange]) -> DayChange? {
        guard !changes.isEmpty else { return nil }
        return DayChange(amount: changes.reduce(0) { $0 + $1.amount },
                         value: changes.reduce(0) { $0 + $1.value })
    }
}
