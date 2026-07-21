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
}
