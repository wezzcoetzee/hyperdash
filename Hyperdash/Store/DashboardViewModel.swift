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
    }

    @Published private(set) var state: LoadState = .idle
    @Published private(set) var totals = Totals()

    func load(wallets: [Wallet], session: HyperliquidSession) async {
        guard !wallets.isEmpty else {
            totals = Totals()
            state = .loaded
            return
        }
        if state != .loaded { state = .loading }
        do {
            let snapshots = try await withThrowingTaskGroup(of: WalletSnapshot.self) { group in
                for wallet in wallets {
                    group.addTask { try await session.info.snapshot(address: wallet.address) }
                }
                var result: [WalletSnapshot] = []
                for try await snapshot in group { result.append(snapshot) }
                return result
            }
            totals = snapshots.reduce(into: Totals()) { acc, snap in
                acc.balance += snap.accountBalanceUSDC
                acc.openPnl += snap.totalUnrealizedPnl
                acc.openExposure += snap.sideExposure.total
                acc.walletCount += 1
            }
            state = .loaded
        } catch {
            state = .failed(error.userMessage)
        }
    }
}
