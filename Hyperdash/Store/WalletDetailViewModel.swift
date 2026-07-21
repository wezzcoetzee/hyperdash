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

    func load(session: HyperliquidSession) async {
        if snapshot == nil { state = .loading }
        do {
            async let snap = session.info.snapshot(address: wallet.address)
            let port = try? await session.info.portfolio(address: wallet.address)
            snapshot = try await snap
            if let port { portfolio = port }
            state = .loaded
        } catch {
            if snapshot == nil { state = .failed(error.userMessage) }
        }
    }
}
