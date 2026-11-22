import Foundation

/// One OHLCV bar from `candleSnapshot`. The wire carries prices as strings
/// and times as epoch milliseconds (`t` open, `T` close).
struct Candle: Decodable, Equatable, Identifiable {
    let openTime: Date
    let closeTime: Date
    let open: Double
    let high: Double
    let low: Double
    let close: Double
    let volume: Double

    var id: Date { openTime }
    var isGain: Bool { close >= open }
    var midTime: Date { openTime.addingTimeInterval(closeTime.timeIntervalSince(openTime) / 2) }
}

extension Candle {
    private enum CodingKeys: String, CodingKey { case t, T, o, c, h, l, v }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        /// A price that doesn't parse is a bad response, not a zero: a zero
        /// candle would drag the whole chart's scale to the floor.
        func number(_ key: CodingKeys) throws -> Double {
            let raw = try container.decode(String.self, forKey: key)
            guard let value = Double(raw) else {
                throw DecodingError.dataCorruptedError(forKey: key, in: container, debugDescription: "Not a number: \(raw)")
            }
            return value
        }

        openTime = Date(timeIntervalSince1970: Double(try container.decode(Int.self, forKey: .t)) / 1000)
        closeTime = Date(timeIntervalSince1970: Double(try container.decode(Int.self, forKey: .T)) / 1000)
        open = try number(.o)
        high = try number(.h)
        low = try number(.l)
        close = try number(.c)
        volume = try number(.v)
    }
}

struct PriceChange: Equatable {
    let absolute: Double
    /// `nil` when the opening price gives nothing to divide by.
    let percent: Double?

    init?(over candles: [Candle]) {
        guard let first = candles.first, let last = candles.last else { return nil }
        absolute = last.close - first.open
        percent = first.open > 0 ? absolute / first.open * 100 : nil
    }
}

enum CandleRange: String, CaseIterable, Identifiable {
    case day, week, month, quarter, year

    /// What the TP/SL ladder offers: longer windows swing far outside the
    /// ladder's price scale and would only draw as streaks along its edges.
    static let ladder: [CandleRange] = [.day, .week]

    var id: String { rawValue }

    var label: String {
        switch self {
        case .day: return "1D"
        case .week: return "1W"
        case .month: return "1M"
        case .quarter: return "3M"
        case .year: return "1Y"
        }
    }

    var accessibilityLabel: String {
        switch self {
        case .day: return "one day"
        case .week: return "one week"
        case .month: return "one month"
        case .quarter: return "three months"
        case .year: return "one year"
        }
    }

    var interval: String {
        switch self {
        case .day: return "15m"
        case .week: return "1h"
        case .month: return "4h"
        case .quarter, .year: return "1d"
        }
    }

    private var days: Double {
        switch self {
        case .day: return 1
        case .week: return 7
        case .month: return 30
        case .quarter: return 90
        case .year: return 365
        }
    }

    /// Epoch milliseconds at the start of the window ending at `end`.
    func startTime(endingAt end: Date) -> Int {
        Int((end.timeIntervalSince1970 - days * 86_400) * 1000)
    }

    func request(coin: String, now: Date) -> [String: Any] {
        [
            "type": "candleSnapshot",
            "req": [
                "coin": coin,
                "interval": interval,
                "startTime": startTime(endingAt: now),
                "endTime": Int(now.timeIntervalSince1970 * 1000),
            ] as [String: Any],
        ]
    }
}

enum ChartStyle: String, CaseIterable, Identifiable {
    case candles, line

    static let standard: ChartStyle = .candles

    var id: String { rawValue }

    var label: String {
        switch self {
        case .candles: return "Candles"
        case .line: return "Line"
        }
    }
}
