import SwiftUI

struct WalletsListView: View {
    @EnvironmentObject private var store: WalletStore
    @EnvironmentObject private var settings: AppSettings
    @EnvironmentObject private var expiryStore: AgentKeyExpiryStore
    @State private var showingAdd = false

    var body: some View {
        NavigationStack {
            Group {
                if store.wallets.isEmpty {
                    emptyState
                } else {
                    list
                }
            }
            .navigationTitle("Wallets")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showingAdd = true } label: {
                        Image(systemName: "plus")
                    }
                }
                ToolbarItem(placement: .topBarLeading) {
                    NetworkBadge(network: settings.network)
                }
            }
            .sheet(isPresented: $showingAdd) {
                AddWalletView()
            }
        }
    }

    private var list: some View {
        List {
            ForEach(store.wallets) { wallet in
                NavigationLink(value: wallet) {
                    WalletRow(wallet: wallet, hasKey: store.hasAgentKey(wallet),
                              expiry: expiryStore.expiries[wallet.id])
                }
            }
            .onDelete { indexSet in
                indexSet.map { store.wallets[$0] }.forEach(store.remove)
            }
        }
        .navigationDestination(for: Wallet.self) { wallet in
            WalletDetailView(wallet: wallet)
        }
        .task(id: refreshKey) {
            await expiryStore.refresh(wallets: store.wallets, session: settings.session,
                                      keyProvider: store.agentKey)
        }
    }

    /// Re-run agent-key expiry refresh when the network changes or wallets are added/removed.
    private var refreshKey: String {
        "\(settings.network.rawValue)-\(store.wallets.map(\.id.uuidString).joined())"
    }

    private var emptyState: some View {
        ContentUnavailableView {
            Label("No wallets yet", systemImage: "wallet.bifold")
        } description: {
            Text("Add a Hyperliquid wallet by its public address to start monitoring.")
        } actions: {
            Button("Add Wallet") { showingAdd = true }
                .buttonStyle(.borderedProminent)
        }
    }
}

struct WalletRow: View {
    let wallet: Wallet
    let hasKey: Bool
    var expiry: AgentKeyExpiry?

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "wallet.bifold.fill")
                .foregroundStyle(.tint)
                .font(.title2)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(wallet.name).font(.headline)
                Text(wallet.shortAddress)
                    .font(.subheadline.monospaced())
                    .foregroundStyle(.secondary)
            }
            Spacer()
            keyIndicator
        }
        .padding(.vertical, 4)
    }

    @ViewBuilder
    private var keyIndicator: some View {
        if let expiry, expiry.status() != .healthy {
            AgentKeyBadge(expiry: expiry, compact: true)
        } else if hasKey {
            Image(systemName: "key.fill")
                .foregroundStyle(.secondary)
                .font(.caption)
                .accessibilityLabel("Trading enabled")
        }
    }
}

struct NetworkBadge: View {
    let network: HyperliquidNetwork

    private var fillColor: Color { network == .mainnet ? .gain : .caution }
    private var textColor: Color { network == .mainnet ? .gainText : .cautionText }

    var body: some View {
        Text(network.displayName.uppercased())
            .font(.caption2.weight(.bold))
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(fillColor.opacity(Theme.networkFillOpacity))
            .foregroundStyle(textColor)
            .clipShape(Capsule())
    }
}
