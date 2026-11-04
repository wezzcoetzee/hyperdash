import Foundation
import Combine

/// One wallet's live data as last fetched.
struct WalletData {
    let snapshot: WalletSnapshot
    let portfolio: PortfolioResponse
    let fetchedAt: Date
    let dayChange: DayChange?

    init(snapshot: WalletSnapshot, portfolio: PortfolioResponse, fetchedAt: Date = Date()) {
        self.snapshot = snapshot
        self.portfolio = portfolio
        self.fetchedAt = fetchedAt
        self.dayChange = DayChange(dayPnl: portfolio.pnlSeries(.day), value: snapshot.accountBalanceUSDC)
    }

    var value: Double { snapshot.accountBalanceUSDC }
    var positionCount: Int { snapshot.openPositions.count }

    var maxLeverage: Int? {
        snapshot.openPositions.map(\.position.leverage.value).max()
    }

    /// Distance to liquidation, in percent of mark, of the position closest to it.
    var nearestLiquidationPct: Double? {
        snapshot.openPositions.compactMap { entry in
            snapshot.mark(for: entry).flatMap { entry.position.liquidationDistancePct(markPrice: $0) }
        }.min()
    }
}

private extension Dictionary where Key == UUID, Value == WalletData {
    /// A full load and a single-wallet refresh can overlap; the slower, older
    /// response must not overwrite the newer one.
    mutating func storeIfNewer(_ fresh: WalletData, for id: UUID) {
        if let current = self[id], current.fetchedAt > fresh.fetchedAt { return }
        self[id] = fresh
    }
}

/// The one cache of per-wallet snapshots and portfolios. Dashboard, the wallets
/// tab and wallet detail all read from it, so their numbers always agree and a
/// screen opened after another has fetched renders immediately.
@MainActor
final class WalletDataStore: ObservableObject {
    enum LoadState: Equatable {
        case idle
        case loading
        case loaded
        case failed(String)
    }

    @Published private(set) var data: [UUID: WalletData] = [:]
    @Published private(set) var state: LoadState = .idle

    /// Which network `data` belongs to; switching clears the cache so testnet
    /// figures never show under mainnet, and drops responses still in flight.
    private var network: HyperliquidNetwork?

    var hasData: Bool { !data.isEmpty }

    /// The oldest fetch among the cached wallets: how stale the screen could be.
    var updatedAt: Date? { data.values.map(\.fetchedAt).min() }

    /// Fetches every wallet. One wallet failing keeps its previous data (if any)
    /// rather than failing the batch; only an all-wallet failure is reported.
    func load(wallets: [Wallet], session: HyperliquidSession) async {
        adopt(session.network)
        let ids = Set(wallets.map(\.id))
        data = data.filter { ids.contains($0.key) }
        guard !wallets.isEmpty else {
            state = .loaded
            return
        }
        if data.isEmpty { state = .loading }

        let previous = data
        let outcomes = await withTaskGroup(of: (UUID, Result<WalletData, Error>).self) { group in
            for wallet in wallets {
                group.addTask {
                    (wallet.id, await Self.fetch(wallet, session: session, previous: previous[wallet.id]))
                }
            }
            var acc: [(UUID, Result<WalletData, Error>)] = []
            for await outcome in group { acc.append(outcome) }
            return acc
        }
        // A cancelled load (scene went inactive, e.g. the Face ID prompt) is not
        // a failure; the next load picks up where this one left off.
        guard session.network == network, !Task.isCancelled else { return }

        var next = data
        var firstError: Error?
        for (id, outcome) in outcomes {
            switch outcome {
            case .success(let fresh): next.storeIfNewer(fresh, for: id)
            case .failure(let error): firstError = firstError ?? error
            }
        }
        data = next

        if outcomes.contains(where: { (try? $0.1.get()) != nil }) {
            state = .loaded
        } else {
            state = .failed((firstError ?? HyperliquidError.invalidResponse).userMessage)
        }
    }

    /// Fetches one wallet into the cache. Throws when its snapshot can't be loaded.
    func refresh(_ wallet: Wallet, session: HyperliquidSession) async throws {
        adopt(session.network)
        let fresh = try await Self.fetch(wallet, session: session, previous: data[wallet.id]).get()
        guard session.network == network else { return }
        data.storeIfNewer(fresh, for: wallet.id)
    }

    private func adopt(_ network: HyperliquidNetwork) {
        guard network != self.network else { return }
        self.network = network
        data = [:]
        state = .idle
    }

    /// A missing portfolio only blanks the charts, so it falls back to the last
    /// one fetched (or an empty one) instead of failing the wallet.
    private nonisolated static func fetch(
        _ wallet: Wallet, session: HyperliquidSession, previous: WalletData?
    ) async -> Result<WalletData, Error> {
        async let snapshot = session.info.snapshot(address: wallet.address)
        let portfolio = (try? await session.info.portfolio(address: wallet.address))
            ?? previous?.portfolio ?? PortfolioResponse(windows: [:])
        do {
            return .success(WalletData(snapshot: try await snapshot, portfolio: portfolio))
        } catch {
            return .failure(error)
        }
    }
}
