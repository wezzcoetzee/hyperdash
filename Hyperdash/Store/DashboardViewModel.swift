import Foundation
import Combine

/// Aggregates the shared `WalletDataStore` cache across every tracked wallet
/// into portfolio totals. Fetching lives in the store; this only derives.
@MainActor
final class DashboardViewModel: ObservableObject {
    struct Totals {
        var balance: Double = 0
        var openPnl: Double = 0
        var openExposure: Double = 0
        var walletCount: Int = 0
        var exposure = SideExposure(long: .init(), short: .init())
    }

    /// A single wallet's open PnL, both in dollars and as a share of its balance,
    /// used to rank the best and worst performers.
    struct WalletPnL: Identifiable, Equatable {
        let id: UUID
        let name: String
        let icon: WalletIcon
        let pnl: Double
        let pnlPercent: Double
    }

    /// One spot asset merged across every tracked wallet, so two wallets holding
    /// BTC report a single line. `usdValue` is nil only when no wallet could
    /// price the coin.
    struct SpotHolding: Identifiable, Equatable {
        let coin: String
        let amount: Double
        let usdValue: Double?
        let walletCount: Int

        var id: String { coin }
    }

    private struct Entry {
        let wallet: Wallet
        let snapshot: WalletSnapshot
        let portfolio: PortfolioResponse
    }

    @Published private(set) var totals = Totals()
    @Published private(set) var portfolios: [PortfolioResponse] = []
    @Published private(set) var topWinner: WalletPnL?
    @Published private(set) var topLoser: WalletPnL?
    @Published private(set) var topDollarWinner: WalletPnL?
    @Published private(set) var spotHoldings: [SpotHolding] = []
    @Published var chartPeriod = AppSettings.chartPeriod {
        didSet { AppSettings.chartPeriod = chartPeriod }
    }

    var accountValueChart: [PortfolioPoint] {
        PortfolioAggregator.sum(portfolios.map { $0.accountValueSeries(chartPeriod) })
    }

    var pnlChart: [PortfolioPoint] {
        PortfolioAggregator.sum(portfolios.map { $0.pnlSeries(chartPeriod) })
    }

    /// Re-derives every figure from the cached data, in wallet order. Wallets
    /// with nothing cached yet are left out rather than counted as zero.
    func update(wallets: [Wallet], data: [UUID: WalletData]) {
        let results = wallets.compactMap { wallet in
            data[wallet.id].map { Entry(wallet: wallet, snapshot: $0.snapshot, portfolio: $0.portfolio) }
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
        rankPnL(results)
        spotHoldings = Self.mergeSpot(results)
    }

    /// Finds the best and worst wallets by open PnL as a percentage of balance.
    /// Only wallets with a positive balance and non-zero open PnL are ranked, so
    /// idle wallets don't crowd out the leaders. Winner and loser collapse to a
    /// single highlight when one wallet tops both ends.
    private func rankPnL(_ results: [Entry]) {
        let ranked = results.map { data -> WalletPnL in
            let balance = data.snapshot.accountBalanceUSDC
            let pnl = data.snapshot.totalUnrealizedPnl
            let percent = balance > 0 ? (pnl / balance) * 100 : 0
            return WalletPnL(id: data.wallet.id, name: data.wallet.name,
                             icon: data.wallet.icon, pnl: pnl, pnlPercent: percent)
        }
        .filter { $0.pnl != 0 }
        .sorted { $0.pnlPercent > $1.pnlPercent }

        topWinner = ranked.first { $0.pnlPercent > 0 }
        let loser = ranked.last { $0.pnlPercent < 0 }
        topLoser = (loser?.id == topWinner?.id) ? nil : loser

        // The percentage leader is often a small wallet; the dollar leader is the
        // one that actually moved the portfolio. Only worth its own row when the
        // two are different wallets.
        let byDollars = ranked.max { $0.pnl < $1.pnl }
        topDollarWinner = (byDollars?.pnl ?? 0) > 0 && byDollars?.id != topWinner?.id ? byDollars : nil
    }

    /// Merges every wallet's spot balances into one line per coin, summing both
    /// the token amount and its USD value.
    private static func mergeSpot(_ results: [Entry]) -> [SpotHolding] {
        var merged: [String: (amount: Double, usd: Double, priced: Bool, wallets: Int)] = [:]
        for data in results {
            for balance in data.snapshot.spot.nonZeroBalances {
                var entry = merged[balance.coin] ?? (0, 0, false, 0)
                entry.amount += balance.totalValue
                if let usd = data.snapshot.usdValue(of: balance) {
                    entry.usd += usd
                    entry.priced = true
                }
                entry.wallets += 1
                merged[balance.coin] = entry
            }
        }
        return merged.map { coin, entry in
            SpotHolding(coin: coin, amount: entry.amount,
                        usdValue: entry.priced ? entry.usd : nil,
                        walletCount: entry.wallets)
        }
        .sorted { a, b in
            let left = a.usdValue ?? 0, right = b.usdValue ?? 0
            return left == right ? a.coin < b.coin : left > right
        }
    }
}
