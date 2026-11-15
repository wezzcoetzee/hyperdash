import Foundation

/// One executed fill from the `userFillsByTime` info request (aggregated by time).
/// Only the fields the Activity screen reads are decoded; `feeToken` may be absent.
struct Fill: Decodable, Equatable, Identifiable {
    /// Trade id; unique per fill, so pages that overlap on a millisecond can be deduped.
    let tid: Int
    var id: Int { tid }
    let coin: String
    let price: Double
    let size: Double
    let isBuy: Bool
    let timeMs: Int
    /// Hyperliquid's own label: "Open Long", "Close Short", "Buy", "Sell", ...
    let dir: String
    let closedPnl: Double
    let fee: Double
    let feeToken: String?

    var time: Date { Date(timeIntervalSince1970: Double(timeMs) / 1000) }

    /// Fees are only dollar-denominated when paid in USDC. A fill without a
    /// token is treated as USDC, which is what perps always charge.
    var feeIsUSDC: Bool { feeToken == nil || feeToken == "USDC" }

    /// Closed PnL is zero for fills that open or add to a position, which have
    /// nothing realised; the UI shows a dash for those rather than "$0.00".
    var realisesPnl: Bool { closedPnl != 0 || dir.hasPrefix("Close") }

    private enum CodingKeys: String, CodingKey {
        case tid, coin, px, sz, side, time, dir, closedPnl, fee, feeToken
    }

    init(tid: Int = 0, coin: String, price: Double, size: Double, isBuy: Bool, timeMs: Int,
         dir: String, closedPnl: Double, fee: Double, feeToken: String? = "USDC") {
        self.tid = tid
        self.coin = coin
        self.price = price
        self.size = size
        self.isBuy = isBuy
        self.timeMs = timeMs
        self.dir = dir
        self.closedPnl = closedPnl
        self.fee = fee
        self.feeToken = feeToken
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        tid = try c.decode(Int.self, forKey: .tid)
        coin = try c.decode(String.self, forKey: .coin)
        price = try c.decode(String.self, forKey: .px).hlDouble
        size = try c.decode(String.self, forKey: .sz).hlDouble
        isBuy = try c.decode(String.self, forKey: .side) == "B"
        timeMs = try c.decode(Int.self, forKey: .time)
        dir = try c.decodeIfPresent(String.self, forKey: .dir) ?? ""
        closedPnl = try c.decodeIfPresent(String.self, forKey: .closedPnl)?.hlDouble ?? 0
        fee = try c.decodeIfPresent(String.self, forKey: .fee)?.hlDouble ?? 0
        feeToken = try c.decodeIfPresent(String.self, forKey: .feeToken)
    }
}

/// Realised PnL for one local calendar day.
struct DailyPnL: Equatable {
    /// Start of the local day.
    let day: Date
    /// Newest first.
    let fills: [Fill]

    var closedPnl: Double { fills.reduce(0) { $0 + $1.closedPnl } }
    /// USDC fees only; fees paid in another token have no dollar value here.
    var fees: Double { fills.filter(\.feeIsUSDC).reduce(0) { $0 + $1.fee } }
    var net: Double { closedPnl - fees }
}

/// A month of fills bucketed by local day, plus the layout and shading
/// questions the calendar asks. Pure: calendar and time zone are injected.
struct ActivityMonth: Equatable {
    /// Tint opacity bounds: a quiet day stays visible, the biggest never hides its label.
    static let opacityRange: ClosedRange<Double> = 0.15...0.85

    let calendar: Calendar
    /// Start of the first day of the month.
    let start: Date
    let days: [Date: DailyPnL]

    init(fills: [Fill], containing date: Date, calendar: Calendar) {
        self.calendar = calendar
        let interval = calendar.dateInterval(of: .month, for: date)
            ?? DateInterval(start: calendar.startOfDay(for: date), duration: 0)
        start = interval.start
        let inMonth = fills.filter { interval.contains($0.time) }
        days = Dictionary(grouping: inMonth) { calendar.startOfDay(for: $0.time) }
            .reduce(into: [:]) { result, entry in
                result[entry.key] = DailyPnL(day: entry.key, fills: entry.value.sorted { $0.timeMs > $1.timeMs })
            }
    }

    /// The month's fetch window as epoch milliseconds, `end` inclusive.
    static func fetchWindowMs(containing date: Date, calendar: Calendar) -> (start: Int, end: Int) {
        let interval = calendar.dateInterval(of: .month, for: date)
            ?? DateInterval(start: date, duration: 0)
        return (Int(interval.start.timeIntervalSince1970 * 1000),
                Int(interval.end.timeIntervalSince1970 * 1000) - 1)
    }

    var net: Double { days.values.reduce(0) { $0 + $1.net } }
    var fees: Double { days.values.reduce(0) { $0 + $1.fees } }
    var maxAbsNet: Double { days.values.map { abs($0.net) }.max() ?? 0 }

    /// Every day of the month, in order.
    var monthDays: [Date] {
        let count = calendar.range(of: .day, in: .month, for: start)?.count ?? 0
        return (0..<count).compactMap { calendar.date(byAdding: .day, value: $0, to: start) }
    }

    /// Blank cells before day 1, given the calendar's first weekday.
    var leadingBlanks: Int {
        (calendar.component(.weekday, from: start) - calendar.firstWeekday + 7) % 7
    }

    /// Column headers in grid order, starting at the calendar's first weekday.
    var weekdayHeaders: [String] {
        let symbols = calendar.veryShortStandaloneWeekdaySymbols
        guard symbols.count == 7 else { return [] }
        return (0..<7).map { symbols[(calendar.firstWeekday - 1 + $0) % 7] }
    }

    func pnl(on day: Date) -> DailyPnL? {
        days[calendar.startOfDay(for: day)]
    }

    /// Tint strength for a day, or nil when it should use the neutral fill
    /// (no fills netting to exactly zero). Proportional to the month's biggest day.
    func tintOpacity(for net: Double) -> Double? {
        guard net != 0, maxAbsNet > 0 else { return nil }
        let share = abs(net) / maxAbsNet
        return min(max(share, Self.opacityRange.lowerBound), Self.opacityRange.upperBound)
    }
}
