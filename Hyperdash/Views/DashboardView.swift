import SwiftUI

struct DashboardView: View {
    @EnvironmentObject private var settings: AppSettings
    @EnvironmentObject private var store: WalletStore
    @EnvironmentObject private var expiryStore: AgentKeyExpiryStore
    @StateObject private var model = DashboardViewModel()

    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if store.wallets.isEmpty {
                        emptyState
                    } else if case .failed(let message) = model.state, !model.hasLoaded {
                        errorState(message)
                    } else {
                        stats
                    }
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Dashboard")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    NetworkBadge(network: settings.network)
                }
            }
            .refreshable {
                await model.load(wallets: store.wallets, session: settings.session)
                await expiryStore.refresh(wallets: store.wallets, session: settings.session,
                                          keyProvider: store.agentKey)
            }
            .task(id: reloadKey) {
                await model.load(wallets: store.wallets, session: settings.session)
                await expiryStore.refresh(wallets: store.wallets, session: settings.session,
                                          keyProvider: store.agentKey)
            }
        }
    }

    /// Reload when the network changes or wallets are added/removed.
    private var reloadKey: String {
        "\(settings.network.rawValue)-\(store.wallets.map(\.id.uuidString).joined())"
    }

    private var loading: Bool { model.state == .loading }

    @ViewBuilder
    private var stats: some View {
        Text("All configured Hyperliquid wallets.")
            .font(.subheadline)
            .foregroundStyle(.secondary)

        let warnings = expiryStore.expiringSoon
        if !warnings.isEmpty {
            keyWarnings(warnings)
        }

        let totals = model.totals
        DashboardSummaryCard(totals: totals)
            .redacted(reason: loading ? .placeholder : [])

        if model.topWinner != nil || model.topLoser != nil {
            VStack(alignment: .leading, spacing: 12) {
                Text("PnL Leaders".uppercased())
                    .font(.caption2.weight(.semibold)).tracking(0.5)
                    .foregroundStyle(.secondary)
                LazyVGrid(columns: columns, spacing: 12) {
                    if let winner = model.topWinner {
                        WalletPnLCard(title: "Top Winner", entry: winner)
                    }
                    if let loser = model.topLoser {
                        WalletPnLCard(title: "Top Loser", entry: loser)
                    }
                }
            }
            .redacted(reason: loading ? .placeholder : [])
        }

        if totals.exposure.total > 0 {
            VStack(alignment: .leading, spacing: 12) {
                Text("Open Interest".uppercased())
                    .font(.caption2.weight(.semibold)).tracking(0.5)
                    .foregroundStyle(.secondary)
                ShortLongRatioCard(exposure: totals.exposure)
            }
            .padding(12)
            .background(Color(.secondarySystemGroupedBackground),
                        in: RoundedRectangle(cornerRadius: Theme.surfaceRadius))
            .redacted(reason: loading ? .placeholder : [])
        }

        PortfolioChartCard(title: "Account Value", period: $model.chartPeriod,
                           points: model.accountValueChart, kind: .accountValue)
            .redacted(reason: loading ? .placeholder : [])
        PortfolioChartCard(title: "PnL", period: $model.chartPeriod,
                           points: model.pnlChart, kind: .pnl)
            .redacted(reason: loading ? .placeholder : [])
    }

    private func keyWarnings(_ ids: [UUID: AgentKeyExpiry]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Agent keys need attention", systemImage: "key.slash")
                .font(.headline).foregroundStyle(.cautionText)
            ForEach(store.wallets.filter { ids[$0.id] != nil }) { wallet in
                HStack {
                    Text(wallet.name).font(.subheadline)
                    Spacer()
                    AgentKeyBadge(expiry: ids[wallet.id]!)
                }
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.caution.opacity(Theme.badgeFillOpacity),
                    in: RoundedRectangle(cornerRadius: Theme.surfaceRadius))
    }

    private var emptyState: some View {
        ContentUnavailableView {
            Label("No wallets yet", systemImage: "chart.bar")
        } description: {
            Text("Add a wallet to see your combined portfolio totals.")
        }
        .frame(maxWidth: .infinity, minHeight: 300)
    }

    private func errorState(_ message: String) -> some View {
        VStack(spacing: 12) {
            Label("Couldn't load dashboard", systemImage: "wifi.exclamationmark")
                .font(.headline)
            Text(message).font(.caption).foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button("Retry") { Task { await model.load(wallets: store.wallets, session: settings.session) } }
                .buttonStyle(.bordered)
        }
        .frame(maxWidth: .infinity, minHeight: 300)
    }
}
