import Foundation

/// Drives the Activity screen and the wallet detail row that leads into it.
/// Months are fetched once and cached; the cache is dropped when the network changes.
@MainActor
final class ActivityViewModel: ObservableObject {
    enum MonthState: Equatable {
        case loading
        case loaded(ActivityMonth)
        case failed
    }

    let wallet: Wallet
    let calendar: Calendar
    private let now: () -> Date

    @Published private(set) var month: Date
    @Published var selectedDay: Date?
    @Published private var months: [Date: ActivityMonth] = [:]
    @Published private var failedMonths: Set<Date> = []
    private var cacheNetwork: HyperliquidNetwork?

    init(wallet: Wallet, calendar: Calendar = .current, now: @escaping () -> Date = Date.init) {
        self.wallet = wallet
        self.calendar = calendar
        self.now = now
        let current = calendar.dateInterval(of: .month, for: now())?.start ?? now()
        month = current
        selectedDay = calendar.startOfDay(for: now())
    }

    var currentMonthStart: Date {
        calendar.dateInterval(of: .month, for: now())?.start ?? month
    }

    var isCurrentMonth: Bool { month == currentMonthStart }

    func state(for monthStart: Date) -> MonthState {
        if let loaded = months[monthStart] { return .loaded(loaded) }
        return failedMonths.contains(monthStart) ? .failed : .loading
    }

    var state: MonthState { state(for: month) }

    func step(by months: Int) {
        guard let next = calendar.date(byAdding: .month, value: months, to: month),
              next <= currentMonthStart else { return }
        month = next
        selectedDay = defaultSelection(in: next)
    }

    /// Today in the current month; otherwise the latest day with fills once they load.
    private func defaultSelection(in monthStart: Date) -> Date? {
        if monthStart == currentMonthStart { return calendar.startOfDay(for: now()) }
        if case .loaded(let loaded) = state(for: monthStart) { return loaded.days.keys.max() }
        return nil
    }

    /// Fetches `monthStart` unless cached. `force` refetches while keeping the
    /// old numbers on screen, so pull-to-refresh never blanks the calendar.
    func load(_ monthStart: Date, session: HyperliquidSession, force: Bool = false) async {
        let network = session.network
        if cacheNetwork != network {
            months = [:]
            failedMonths = []
            cacheNetwork = network
        }
        if months[monthStart] != nil, !force { return }
        failedMonths.remove(monthStart)

        let window = ActivityMonth.fetchWindowMs(containing: monthStart, calendar: calendar)
        do {
            let fills = try await session.info.fills(
                address: wallet.address, startMs: window.start, endMs: window.end)
            guard cacheNetwork == network, !Task.isCancelled else { return }
            months[monthStart] = ActivityMonth(fills: fills, containing: monthStart, calendar: calendar)
            if monthStart == month, selectedDay == nil { selectedDay = defaultSelection(in: monthStart) }
        } catch {
            guard cacheNetwork == network, !Task.isCancelled else { return }
            if months[monthStart] == nil { failedMonths.insert(monthStart) }
        }
    }
}
