import Foundation

/// Drives the Activity screen and the wallet detail row that leads into it.
/// Months are fetched once and cached per network, so a network switch can
/// never serve another network's numbers.
@MainActor
final class ActivityViewModel: ObservableObject {
    enum MonthState: Equatable {
        case loading
        case loaded(ActivityMonth)
        case failed
    }

    private struct Key: Hashable {
        let network: HyperliquidNetwork
        let month: Date
    }

    let wallet: Wallet
    let calendar: Calendar
    private let now: () -> Date

    @Published private(set) var month: Date
    @Published var selectedDay: Date?
    @Published private var months: [Key: ActivityMonth] = [:]
    @Published private var failedMonths: Set<Key> = []

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

    func state(for monthStart: Date, network: HyperliquidNetwork) -> MonthState {
        let key = Key(network: network, month: monthStart)
        if let loaded = months[key] { return .loaded(loaded) }
        return failedMonths.contains(key) ? .failed : .loading
    }

    func step(by delta: Int, network: HyperliquidNetwork) {
        guard let next = calendar.date(byAdding: .month, value: delta, to: month),
              next <= currentMonthStart else { return }
        month = next
        selectedDay = defaultSelection(in: next, network: network)
    }

    /// Today in the current month; otherwise the latest day with fills once they load.
    private func defaultSelection(in monthStart: Date, network: HyperliquidNetwork) -> Date? {
        if monthStart == currentMonthStart { return calendar.startOfDay(for: now()) }
        if case .loaded(let loaded) = state(for: monthStart, network: network) { return loaded.days.keys.max() }
        return nil
    }

    /// Fetches `monthStart` unless cached. `force` refetches while keeping the
    /// old numbers on screen, so pull-to-refresh never blanks the calendar.
    func load(_ monthStart: Date, session: HyperliquidSession, force: Bool = false) async {
        let network = session.network
        let key = Key(network: network, month: monthStart)
        if months[key] != nil, !force { return }
        failedMonths.remove(key)

        let window = ActivityMonth.fetchWindowMs(containing: monthStart, calendar: calendar)
        do {
            let fills = try await session.info.fills(
                address: wallet.address, startMs: window.start, endMs: window.end)
            guard !Task.isCancelled else { return }
            months[key] = ActivityMonth(fills: fills, containing: monthStart, calendar: calendar)
            if monthStart == month, selectedDay == nil {
                selectedDay = defaultSelection(in: monthStart, network: network)
            }
        } catch {
            guard !Task.isCancelled else { return }
            if months[key] == nil { failedMonths.insert(key) }
        }
    }
}
