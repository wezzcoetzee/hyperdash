import Foundation

/// How the PnL card draws its series. Account value is always a line.
enum PnLChartStyle: String, CaseIterable {
    case line, bars
}

/// One bar of the PnL chart: what was made or lost within a single bucket.
struct PnLBar: Equatable {
    /// Start of the bucket.
    let date: Date
    let delta: Double
}

enum PnLBuckets {
    /// Calendar unit one bar spans for a period.
    static func unit(for period: PortfolioPeriod, points: [PortfolioPoint]) -> Calendar.Component {
        switch period {
        case .day: return .hour
        case .week, .month: return .day
        case .allTime:
            // Months only pay off once there are enough days to fill a chart.
            guard let first = points.first?.date, let last = points.last?.date else { return .day }
            return last.timeIntervalSince(first) > 120 * 86_400 ? .month : .day
        }
    }

    /// Turns a cumulative PnL series into per-bucket deltas. Each bucket's delta
    /// is its last reading minus the previous bucket's last reading; the first
    /// bucket is measured from the series' opening value.
    static func bars(
        from points: [PortfolioPoint],
        unit: Calendar.Component,
        calendar: Calendar = .current
    ) -> [PnLBar] {
        guard let opening = points.first else { return [] }
        var closes: [(start: Date, close: Double)] = []
        for p in points.sorted(by: { $0.date < $1.date }) {
            let start = calendar.dateInterval(of: unit, for: p.date)?.start ?? p.date
            if let last = closes.last, last.start == start {
                closes[closes.count - 1].close = p.value
            } else {
                closes.append((start, p.value))
            }
        }
        var previous = opening.value
        return closes.map { bucket in
            defer { previous = bucket.close }
            return PnLBar(date: bucket.start, delta: bucket.close - previous)
        }
    }
}
