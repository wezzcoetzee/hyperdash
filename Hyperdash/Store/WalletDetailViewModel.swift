import Foundation
import Combine

@MainActor
final class WalletDetailViewModel: ObservableObject {
    enum LoadState: Equatable {
        case idle
        case loading
        case loaded
        case failed(String)
    }

    @Published private(set) var state: LoadState = .idle
    @Published private(set) var snapshot: WalletSnapshot?
    @Published private(set) var portfolio: PortfolioResponse?
    @Published private(set) var fetchedAt: Date?
    @Published var chartPeriod: PortfolioPeriod = .week

    let wallet: Wallet

    init(wallet: Wallet) {
        self.wallet = wallet
    }

    func accountValueChart(_ period: PortfolioPeriod) -> [PortfolioPoint] {
        portfolio?.accountValueSeries(period) ?? []
    }

    func pnlChart(_ period: PortfolioPeriod) -> [PortfolioPoint] {
        portfolio?.pnlSeries(period) ?? []
    }

    /// Shows whatever the shared cache already holds for this wallet, then
    /// refreshes it. The cache stays the source of truth, so later refreshes
    /// from other screens (or auto refresh) flow straight into this one.
    func load(session: HyperliquidSession, store: WalletDataStore) async {
        observe(store)
        if snapshot == nil { state = .loading }
        do {
            try await store.refresh(wallet, session: session)
            state = .loaded
        } catch {
            if snapshot == nil { state = .failed(error.userMessage) }
        }
    }

    private var isObserving = false

    private func observe(_ store: WalletDataStore) {
        guard !isObserving else { return }
        isObserving = true
        let entry = store.$data.map { [id = wallet.id] in $0[id] }
        entry.map { $0?.snapshot }.assign(to: &$snapshot)
        entry.map { $0?.portfolio }.assign(to: &$portfolio)
        entry.map { $0?.fetchedAt }.assign(to: &$fetchedAt)
    }
}
