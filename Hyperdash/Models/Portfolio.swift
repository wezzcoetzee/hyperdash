import Foundation

enum PortfolioPeriod: String, CaseIterable, Identifiable {
    case day, week, month, allTime
    var id: String { rawValue }
    var apiKey: String { rawValue }
    var label: String {
        switch self {
        case .day: return "1D"
        case .week: return "1W"
        case .month: return "1M"
        case .allTime: return "All"
        }
    }
}

struct PortfolioPoint: Decodable, Equatable {
    let date: Date
    let value: Double

    init(date: Date, value: Double) {
        self.date = date
        self.value = value
    }

    init(from decoder: Decoder) throws {
        var c = try decoder.unkeyedContainer()
        let ms = try c.decode(Double.self)
        let raw = try c.decode(String.self)
        date = Date(timeIntervalSince1970: ms / 1000)
        value = raw.hlDouble
    }
}

struct PortfolioWindow: Decodable {
    let accountValueHistory: [PortfolioPoint]
    let pnlHistory: [PortfolioPoint]
}

/// Decodes Hyperliquid's `[[periodKey, window], …]` tuple array into a keyed lookup.
struct PortfolioResponse: Decodable {
    let windows: [String: PortfolioWindow]

    init(windows: [String: PortfolioWindow]) { self.windows = windows }

    init(from decoder: Decoder) throws {
        var outer = try decoder.unkeyedContainer()
        var result: [String: PortfolioWindow] = [:]
        while !outer.isAtEnd {
            var pair = try outer.nestedUnkeyedContainer()
            let key = try pair.decode(String.self)
            let window = try pair.decode(PortfolioWindow.self)
            result[key] = window
        }
        windows = result
    }

    func accountValueSeries(_ period: PortfolioPeriod) -> [PortfolioPoint] {
        windows[period.apiKey]?.accountValueHistory ?? []
    }

    func pnlSeries(_ period: PortfolioPeriod) -> [PortfolioPoint] {
        windows[period.apiKey]?.pnlHistory ?? []
    }
}
