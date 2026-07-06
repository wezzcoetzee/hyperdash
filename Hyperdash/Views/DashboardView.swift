import SwiftUI

struct DashboardView: View {
    @EnvironmentObject private var settings: AppSettings
    @EnvironmentObject private var store: WalletStore
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
                    } else if case .failed(let message) = model.state {
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
            .refreshable { await model.load(wallets: store.wallets, session: settings.session) }
            .task(id: reloadKey) { await model.load(wallets: store.wallets, session: settings.session) }
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

        let totals = model.totals
        LazyVGrid(columns: columns, spacing: 12) {
            VaultStatCard(
                label: "Total Balance",
                value: Format.usd(totals.balance),
                subtitle: "Live exchange data"
            )
            .redacted(reason: loading ? .placeholder : [])
            VaultStatCard(
                label: "Open PnL",
                value: Format.signedUSD(totals.openPnl),
                tint: totals.openPnl == 0 ? .primary : .directionText(isPositive: totals.openPnl >= 0)
            )
            .redacted(reason: loading ? .placeholder : [])
            VaultStatCard(label: "Open Exposure", value: Format.usd(totals.openExposure))
                .redacted(reason: loading ? .placeholder : [])
            VaultStatCard(label: "Wallets", value: "\(totals.walletCount)")
                .redacted(reason: loading ? .placeholder : [])
        }
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
