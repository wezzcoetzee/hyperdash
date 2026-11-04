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
    @Published private(set) var funding = FundingState.loading
    @Published var chartPeriod = AppSettings.chartPeriod {
        didSet { AppSettings.chartPeriod = chartPeriod }
    }

    enum FundingState: Equatable {
        case loading
        case loaded(FundingSummary?)
        case failed
    }

    let wallet: Wallet
    private var fundingNetwork: HyperliquidNetwork?

    init(wallet: Wallet) {
        self.wallet = wallet
    }

    func accountValueChart(_ period: PortfolioPeriod) -> [PortfolioPoint] {
        portfolio?.accountValueSeries(period) ?? []
    }

    func pnlChart(_ period: PortfolioPeriod) -> [PortfolioPoint] {
        portfolio?.pnlSeries(period) ?? []
    }

    /// Snapshot and funding together; funding is its own request so a slow
    /// history never holds up the rest of the screen.
    func refresh(session: HyperliquidSession, store: WalletDataStore) async {
        async let funding: Void = loadFunding(session: session)
        await load(session: session, store: store)
        await funding
    }

    func loadFunding(session: HyperliquidSession) async {
        let network = session.network
        // Keep showing the old numbers on pull-to-refresh, but never across networks.
        if fundingNetwork != network { funding = .loading }
        fundingNetwork = network
        do {
            let payments = try await session.info.funding(
                address: wallet.address, since: FundingSummary.windowStart())
            guard fundingNetwork == network, !Task.isCancelled else { return }
            funding = .loaded(FundingSummary(payments: payments))
        } catch {
            guard fundingNetwork == network, !Task.isCancelled else { return }
            funding = .failed
        }
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
