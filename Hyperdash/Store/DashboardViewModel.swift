import Foundation
import Combine

/// Aggregates live snapshots across every tracked wallet into portfolio totals.
@MainActor
final class DashboardViewModel: ObservableObject {
    enum LoadState: Equatable {
        case idle
        case loading
        case loaded
        case failed(String)
    }

    struct Totals {
        var balance: Double = 0
        var openPnl: Double = 0
        var openExposure: Double = 0
        var walletCount: Int = 0
        var exposure = SideExposure(long: .init(), short: .init())
    }

    private struct WalletData {
        let snapshot: WalletSnapshot
        let portfolio: PortfolioResponse
    }

    @Published private(set) var state: LoadState = .idle
    @Published private(set) var totals = Totals()
    @Published private(set) var portfolios: [PortfolioResponse] = []
    @Published private(set) var hasLoaded = false
    @Published var chartPeriod: PortfolioPeriod = .week

    var accountValueChart: [PortfolioPoint] {
        PortfolioAggregator.sum(portfolios.map { $0.accountValueSeries(chartPeriod) })
    }

    var pnlChart: [PortfolioPoint] {
        PortfolioAggregator.sum(portfolios.map { $0.pnlSeries(chartPeriod) })
    }

    func load(wallets: [Wallet], session: HyperliquidSession) async {
        guard !wallets.isEmpty else {
            totals = Totals()
            portfolios = []
            hasLoaded = true
            state = .loaded
            return
        }
        if state != .loaded { state = .loading }

        let outcomes = await withTaskGroup(of: Result<WalletData, Error>.self) { group in
            for wallet in wallets {
                group.addTask {
                    async let snap = session.info.snapshot(address: wallet.address)
                    let port = (try? await session.info.portfolio(address: wallet.address))
                        ?? PortfolioResponse(windows: [:])
                    do {
                        return .success(WalletData(snapshot: try await snap, portfolio: port))
                    } catch {
                        return .failure(error)
                    }
                }
            }
            var acc: [Result<WalletData, Error>] = []
            for await outcome in group { acc.append(outcome) }
            return acc
        }

        let results = outcomes.compactMap { try? $0.get() }
        guard !results.isEmpty else {
            let message = outcomes.compactMap { outcome -> String? in
                if case .failure(let error) = outcome { return error.userMessage }
                return nil
            }.first ?? HyperliquidError.invalidResponse.userMessage
            state = .failed(message)
            return
        }

        portfolios = results.map(\.portfolio)
        var next = results.reduce(into: Totals()) { acc, r in
            acc.balance += r.snapshot.accountBalanceUSDC
            acc.openPnl += r.snapshot.totalUnrealizedPnl
            acc.openExposure += r.snapshot.sideExposure.total
            acc.walletCount += 1
        }
        next.exposure = SideExposure.combined(results.map { $0.snapshot.sideExposure })
        totals = next
        hasLoaded = true
        state = .loaded
    }
}
