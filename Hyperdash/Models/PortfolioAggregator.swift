import Foundation

enum PortfolioAggregator {
    /// Sum of multiple step time series over the union of their timestamps,
    /// carrying each series' last observation forward and treating pre-history as 0.
    static func sum(_ series: [[PortfolioPoint]]) -> [PortfolioPoint] {
        let nonEmpty = series.filter { !$0.isEmpty }
        guard !nonEmpty.isEmpty else { return [] }
        if nonEmpty.count == 1 { return nonEmpty[0] }

        let timestamps = Set(nonEmpty.flatMap { $0.map(\.date) }).sorted()
        let sorted = nonEmpty.map { $0.sorted { $0.date < $1.date } }

        return timestamps.map { t in
            let total = sorted.reduce(0.0) { acc, s in
                acc + (Self.value(in: s, atOrBefore: t) ?? 0)
            }
            return PortfolioPoint(date: t, value: total)
        }
    }

    private static func value(in series: [PortfolioPoint], atOrBefore t: Date) -> Double? {
        var result: Double?
        for p in series {
            if p.date <= t { result = p.value } else { break }
        }
        return result
    }

    /// Drops the flat lead-in a series carries before the account did anything.
    ///
    /// Hyperliquid's `allTime` window starts at address creation, so a wallet
    /// funded months later reports a long run of near-constant value. Plotted
    /// as-is that dead run eats half the width and squashes the real history
    /// into the right-hand third. This trims the leading stretch whose own
    /// spread is under `tolerance` of the full series range, keeping one point
    /// of lead so the ramp still reads as a ramp rather than a cliff.
    ///
    /// It only fires when the dead run is a meaningful share of the series
    /// (`minimumShare`) and always leaves `minimumRemaining` points behind, so a
    /// genuinely quiet account keeps a plottable history.
    static func trimmingFlatLeadIn(
        _ points: [PortfolioPoint],
        tolerance: Double = 0.03,
        minimumShare: Double = 0.15,
        minimumRemaining: Int = 8
    ) -> [PortfolioPoint] {
        guard points.count >= 4 else { return points }
        let values = points.map(\.value)
        guard let low = values.min(), let high = values.max() else { return points }
        let range = high - low
        guard range > 0 else { return points }

        let band = range * tolerance
        var runningLow = values[0]
        var runningHigh = values[0]
        var lastFlat = 0
        for (index, value) in values.enumerated() {
            runningLow = min(runningLow, value)
            runningHigh = max(runningHigh, value)
            if runningHigh - runningLow > band { break }
            lastFlat = index
        }

        guard Double(lastFlat) >= Double(points.count) * minimumShare else { return points }
        let ceiling = max(points.count - minimumRemaining, 0)
        let start = min(max(lastFlat - 1, 0), ceiling)
        guard start > 0 else { return points }
        return Array(points[start...])
    }
}
