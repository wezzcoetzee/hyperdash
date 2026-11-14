import SwiftUI

struct DashboardView: View {
    @EnvironmentObject private var settings: AppSettings
    @EnvironmentObject private var store: WalletStore
    @EnvironmentObject private var expiryStore: AgentKeyExpiryStore
    @EnvironmentObject private var walletData: WalletDataStore
    @StateObject private var model = DashboardViewModel()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if store.wallets.isEmpty {
                        emptyState
                    } else if case .failed(let message) = walletData.state, !walletData.hasData {
                        errorState(message)
                    } else {
                        stats
                    }
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Dashboard")
            .navigationDestination(for: Wallet.self) { wallet in
                WalletDetailView(wallet: wallet)
            }
            .navigationDestination(for: PositionGroupKey.self) { key in
                PositionGroupDetailView(key: key)
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    NetworkBadge(network: settings.network)
                }
            }
            .refreshable {
                await walletData.load(wallets: store.wallets, session: settings.session)
                await expiryStore.refresh(wallets: store.wallets, session: settings.session,
                                          keyProvider: store.agentKey)
            }
            // Wallet data itself is fetched (and auto-refreshed) app-wide; see HyperdashApp.
            .task(id: reloadKey) {
                await expiryStore.refresh(wallets: store.wallets, session: settings.session,
                                          keyProvider: store.agentKey)
            }
            .onReceive(walletData.$data) { data in
                model.update(wallets: store.wallets, data: data)
            }
            .onChange(of: store.wallets) { _, wallets in
                model.update(wallets: wallets, data: walletData.data)
            }
        }
    }

    /// Refresh agent-key expiry when the network changes or wallets are added/removed.
    private var reloadKey: String {
        "\(settings.network.rawValue)-\(store.wallets.map(\.id.uuidString).joined())"
    }

    private var loading: Bool { walletData.state == .loading }

    @ViewBuilder
    private var stats: some View {
        Text("All configured Hyperliquid wallets.")
            .font(.subheadline)
            .foregroundStyle(.secondary)

        let warnings = expiryStore.expiringSoon
        if !warnings.isEmpty {
            keyWarnings(warnings)
        }

        // Order and visibility come from Settings → Dashboard layout.
        ForEach(settings.dashboardLayout.visible) { section in
            self.section(section)
        }
    }

    @ViewBuilder
    private func section(_ section: DashboardSection) -> some View {
        switch section {
        case .summary:
            DashboardSummaryCard(totals: model.totals)
                .redacted(reason: loading ? .placeholder : [])
            UpdatedLabel(date: walletData.updatedAt)
        case .pnlLeaders:
            pnlLeaders
        case .spotHoldings:
            if !model.spotHoldings.isEmpty {
                SpotHoldingsCard(holdings: model.spotHoldings)
                    .redacted(reason: loading ? .placeholder : [])
            }
        case .positions:
            let positionGroups = PositionGroup.groups(wallets: store.wallets, data: walletData.data)
            if !positionGroups.isEmpty {
                PositionGroupsSection(groups: positionGroups)
                    .redacted(reason: loading ? .placeholder : [])
            }
        case .openInterest:
            openInterest
        case .accountValueChart:
            chart(title: "Account Value", points: model.accountValueChart, kind: .accountValue)
        case .pnlChart:
            chart(title: "PnL", points: model.pnlChart, kind: .pnl)
        }
    }

    @ViewBuilder
    private var pnlLeaders: some View {
        if model.topWinner != nil || model.topLoser != nil {
            VStack(alignment: .leading, spacing: 12) {
                Text("PnL Leaders".uppercased())
                    .font(.caption2.weight(.semibold)).tracking(0.5)
                    .foregroundStyle(.secondary)
                if let winner = model.topWinner {
                    pnlLeader(WalletPnLRow(title: "Top winner", entry: winner), id: winner.id)
                }
                if let dollarWinner = model.topDollarWinner {
                    Divider()
                    pnlLeader(WalletPnLRow(title: "Biggest gain", entry: dollarWinner,
                                           leadsWithDollars: true), id: dollarWinner.id)
                }
                if model.topWinner != nil && model.topLoser != nil {
                    Divider()
                }
                if let loser = model.topLoser {
                    pnlLeader(WalletPnLRow(title: "Top loser", entry: loser), id: loser.id)
                }
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(.secondarySystemGroupedBackground),
                        in: RoundedRectangle(cornerRadius: Theme.surfaceRadius))
            .redacted(reason: loading ? .placeholder : [])
        }
    }

    @ViewBuilder
    private var openInterest: some View {
        let exposure = model.totals.exposure
        if exposure.total > 0 {
            VStack(alignment: .leading, spacing: 12) {
                Text("Open Interest".uppercased())
                    .font(.caption2.weight(.semibold)).tracking(0.5)
                    .foregroundStyle(.secondary)
                ShortLongRatioCard(exposure: exposure)
            }
            .padding(12)
            .background(Color(.secondarySystemGroupedBackground),
                        in: RoundedRectangle(cornerRadius: Theme.surfaceRadius))
            .redacted(reason: loading ? .placeholder : [])
        }
    }

    /// Redacting a live chart still draws its line; the placeholder holds the
    /// same footprint without pretending to have data.
    @ViewBuilder
    private func chart(title: String, points: [PortfolioPoint], kind: PortfolioChartCard.Kind) -> some View {
        if loading {
            PortfolioChartCard.Placeholder(title: title)
        } else {
            PortfolioChartCard(title: title, period: $model.chartPeriod, points: points, kind: kind)
        }
    }

    /// Makes a leader row tap through to its wallet. Falls back to a plain row if
    /// the wallet vanished between load and render.
    @ViewBuilder
    private func pnlLeader(_ row: WalletPnLRow, id: UUID) -> some View {
        if let wallet = store.wallets.first(where: { $0.id == id }) {
            NavigationLink(value: wallet) { row }
                .buttonStyle(.plain)
        } else {
            row
        }
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
            Button("Retry") { Task { await walletData.load(wallets: store.wallets, session: settings.session) } }
                .buttonStyle(.bordered)
        }
        .frame(maxWidth: .infinity, minHeight: 300)
    }
}
