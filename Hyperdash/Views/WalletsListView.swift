import SwiftUI
import UIKit

struct WalletsListView: View {
    @EnvironmentObject private var store: WalletStore
    @EnvironmentObject private var settings: AppSettings
    @EnvironmentObject private var expiryStore: AgentKeyExpiryStore
    @EnvironmentObject private var walletData: WalletDataStore
    @EnvironmentObject private var alerts: AlertStore
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var showingAdd = false
    /// True only while a finger is down on the eye; resets on release or cancel.
    @GestureState private var holdingPeek = false
    /// VoiceOver can't press and hold, so its action toggles the peek instead.
    @State private var peekToggled = false

    private var isPeeking: Bool { holdingPeek || peekToggled }

    var body: some View {
        NavigationStack {
            Group {
                if store.wallets.isEmpty {
                    emptyState
                } else {
                    list
                }
            }
            .overlay {
                if isPeeking {
                    WalletPeekOverlay(wallets: store.wallets, data: walletData.data)
                        .transition(.opacity)
                }
            }
            .animation(reduceMotion ? nil : .easeOut(duration: 0.15), value: isPeeking)
            .navigationTitle("Wallets")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    NetworkBadge(network: settings.network)
                }
                ToolbarItemGroup(placement: .topBarTrailing) {
                    if !store.wallets.isEmpty {
                        peekButton
                        sortMenu
                        if settings.walletSort == .custom {
                            EditButton()
                        }
                    }
                    Button { showingAdd = true } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel("Add wallet")
                }
            }
            .sensoryFeedback(.impact(weight: .light), trigger: isPeeking) { _, peeking in peeking }
            .onChange(of: isPeeking) { _, peeking in
                guard peeking, !walletData.hasData else { return }
                Task { await walletData.load(wallets: store.wallets, session: settings.session) }
            }
            .sheet(isPresented: $showingAdd) {
                AddWalletView()
            }
        }
    }

    /// A plain view rather than a `Button`: a button claims the touch and never
    /// reports press and release separately. A zero-distance drag does, and its
    /// `@GestureState` resets itself if the system cancels the touch, so the
    /// overlay can't get stuck open.
    private var peekButton: some View {
        Image(systemName: isPeeking ? "eye.fill" : "eye")
            .foregroundStyle(.tint)
            .frame(width: 44, height: 44)
            .contentShape(Rectangle())
            .gesture(DragGesture(minimumDistance: 0).updating($holdingPeek) { _, holding, _ in
                holding = true
            })
            .accessibilityElement()
            .accessibilityLabel("Peek at wallet values")
            .accessibilityHint("Press and hold to show every wallet's value")
            .accessibilityAddTraits(.isButton)
            .accessibilityAction { peekToggled.toggle() }
    }

    private var sortMenu: some View {
        Menu {
            Picker("Sort by", selection: $settings.walletSort) {
                ForEach(WalletSort.allCases) { Text($0.label).tag($0) }
            }
        } label: {
            Label("Sort", systemImage: "arrow.up.arrow.down")
        }
    }

    private var list: some View {
        let ordered = settings.walletSort.sorted(store.wallets, data: walletData.data)
        return List {
            Section {
                ForEach(ordered) { wallet in
                    NavigationLink(value: wallet) {
                        WalletRow(wallet: wallet, hasKey: store.hasAgentKey(wallet),
                                  expiry: expiryStore.expiries[wallet.id],
                                  data: walletData.data[wallet.id],
                                  liquidationThresholdPct: alerts.config.liquidationThresholdPct)
                    }
                    .contextMenu {
                        Button("Copy Address", systemImage: "doc.on.doc") {
                            UIPasteboard.general.string = wallet.address
                        }
                    } preview: {
                        WalletPreview(wallet: wallet, data: walletData.data[wallet.id])
                    }
                }
                .onDelete { indexSet in
                    indexSet.map { ordered[$0] }.forEach(store.remove)
                }
                // Reordering only makes sense against the stored order.
                .onMove(perform: settings.walletSort == .custom ? reorder : nil)
            } footer: {
                UpdatedLabel(date: walletData.updatedAt)
            }
        }
        .navigationDestination(for: Wallet.self) { wallet in
            WalletDetailView(wallet: wallet)
        }
        .refreshable {
            await walletData.load(wallets: store.wallets, session: settings.session)
        }
        .task(id: refreshKey) {
            await expiryStore.refresh(wallets: store.wallets, session: settings.session,
                                      keyProvider: store.agentKey)
        }
    }

    private func reorder(_ source: IndexSet, _ destination: Int) {
        store.move(fromOffsets: source, toOffset: destination)
    }

    /// Re-run agent-key expiry refresh when the network changes or wallets are added/removed.
    /// Sorted so reordering wallets doesn't trigger a refresh.
    private var refreshKey: String {
        "\(settings.network.rawValue)-\(store.wallets.map(\.id.uuidString).sorted().joined())"
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
