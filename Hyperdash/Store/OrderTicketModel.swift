import Foundation
import Combine

/// State behind the keypad order ticket: what's typed, the coin's live mark
/// and limits, and the `OrderTicket` it all adds up to.
@MainActor
final class OrderTicketModel: ObservableObject {
    enum Field { case amount, price }

    @Published private(set) var coin: String
    @Published var isLimit = false {
        didSet { if isLimit, limitPrice.value == 0, let mark { limitPrice.set(mark) } }
    }
    @Published private(set) var amount = KeypadEntry(maxFractionDigits: 2)
    @Published private(set) var limitPrice = KeypadEntry(maxFractionDigits: 6)
    @Published var focus: Field = .amount
    @Published var leverage = 10
    @Published var takeProfitMove: Double?
    @Published var stopLossMove: Double?
    @Published private(set) var mark: Double?
    @Published private(set) var maxLeverage = 1
    @Published private(set) var coins: [String] = []

    /// Collateral free for new margin, from the wallet's snapshot.
    let available: Double
    private let positions: [Position]

    static let refreshInterval: Duration = .seconds(5)

    init(coin: String, available: Double, positions: [Position]) {
        self.coin = coin
        self.available = available
        self.positions = positions
    }

    var notional: Double { amount.value }

    func ticket(isLong: Bool) -> OrderTicket {
        let existing = positions.first { $0.coin == coin }
        return OrderTicket(
            coin: coin, isLong: isLong,
            kind: isLimit ? .limit(price: limitPrice.value) : .market,
            notional: notional, leverage: leverage,
            isCross: existing.map { $0.leverage.type != "isolated" } ?? true,
            takeProfitMove: takeProfitMove, stopLossMove: stopLossMove
        )
    }

    /// The side doesn't change whether a ticket is sendable, only where its
    /// triggers land, so either side answers this.
    var problem: String? {
        guard mark != nil else { return "Loading \(coin) price…" }
        return ticket(isLong: true).problem(available: available, maxLeverage: maxLeverage)
    }

    var size: Double? {
        mark.map { ticket(isLong: true).size(mark: $0) }
    }

    func press(_ key: KeypadEntry.Key) {
        switch focus {
        case .amount: amount.press(key)
        case .price: limitPrice.press(key)
        }
    }

    /// Fills the amount with a share of buying power (available × leverage),
    /// rounded down to whole dollars so fees never tip it over.
    func fill(_ share: Double) {
        focus = .amount
        amount.set((available * Double(leverage) * share).rounded(.down))
    }

    func select(_ coin: String) {
        guard coin != self.coin else { return }
        self.coin = coin
        mark = nil
        limitPrice.set(0)
        takeProfitMove = nil
        stopLossMove = nil
    }

    /// Keeps the coin's limits and mark current while the ticket is open.
    /// Restart it (`.task(id: coin)`) whenever the coin changes.
    func track(session: HyperliquidSession) async {
        if coins.isEmpty { coins = (try? await session.meta.tradablePerpCoins()) ?? [] }
        guard let asset = try? await session.meta.perpAsset(coin: coin), !Task.isCancelled else { return }
        maxLeverage = asset.maxLeverage
        limitPrice = KeypadEntry(limitPrice.text, maxFractionDigits: max(0, 6 - asset.szDecimals))
        let current = positions.first { $0.coin == coin }?.leverage.value
        leverage = min(current ?? 10, asset.maxLeverage)

        while !Task.isCancelled {
            if let price = try? await session.info.allMids()[asset.midKey], price > 0, !Task.isCancelled {
                mark = price
                if isLimit, limitPrice.value == 0 { limitPrice.set(price) }
            }
            try? await Task.sleep(for: Self.refreshInterval)
        }
    }
}
