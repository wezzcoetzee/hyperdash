import SwiftUI

struct WalletDetailView: View {
    let wallet: Wallet

    @EnvironmentObject private var settings: AppSettings
    @EnvironmentObject private var store: WalletStore
    @EnvironmentObject private var expiryStore: AgentKeyExpiryStore
    @StateObject private var model: WalletDetailViewModel
    @State private var tradeContext: TradeContext?
    @State private var priceAlertCoin: AlertCoin?
    @State private var editingAgentKey = false

    private struct AlertCoin: Identifiable { let coin: String; var id: String { coin } }

    init(wallet: Wallet) {
        self.wallet = wallet
        _model = StateObject(wrappedValue: WalletDetailViewModel(wallet: wallet))
    }

    private var canTrade: Bool { store.hasAgentKey(wallet) }

    private var currentWallet: Wallet {
        store.wallets.first { $0.id == wallet.id } ?? wallet
    }

    var body: some View {
        List {
            if let snapshot = model.snapshot {
                content(snapshot)
            } else if case .failed(let message) = model.state {
                errorRow(message)
            } else {
                loadingSkeleton
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle(wallet.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Picker("Wallet icon", selection: iconSelection) {
                        ForEach(WalletIcon.allCases) { icon in
                            Label(icon.label, systemImage: icon.rawValue).tag(icon)
                        }
                    }
                } label: {
                    Image(systemName: currentWallet.icon.rawValue)
                }
                .accessibilityLabel("Choose wallet icon")
            }
        }
        .refreshable { await model.load(session: settings.session) }
        .task(id: settings.network) { await model.load(session: settings.session) }
        .task(id: settings.network) {
            await expiryStore.refresh(wallets: store.wallets, session: settings.session,
                                      keyProvider: store.agentKey)
        }
        .sheet(item: $tradeContext) { context in
            TradeConfirmationView(wallet: wallet, context: context, session: settings.session) {
                Task { await model.load(session: settings.session) }
            }
        }
        .sheet(item: $priceAlertCoin) { item in
            AddPriceAlertView(coin: item.coin)
        }
        .sheet(isPresented: $editingAgentKey) {
            EditAgentKeyView(wallet: currentWallet) {
                Task {
                    await expiryStore.refresh(wallets: store.wallets, session: settings.session,
                                              keyProvider: store.agentKey)
                }
            }
        }
    }

    private var iconSelection: Binding<WalletIcon> {
        Binding(
            get: { currentWallet.icon },
            set: { newIcon in
                var updated = currentWallet
                updated.icon = newIcon
                store.update(updated)
            }
        )
    }

    @ViewBuilder
    private func content(_ snapshot: WalletSnapshot) -> some View {
        Section {
            AccountSummaryCard(snapshot: snapshot)
                .listRowInsets(EdgeInsets(top: 8, leading: 12, bottom: 8, trailing: 12))
                .listRowBackground(Color.clear)
        }

        if !snapshot.perps.openPositions.isEmpty {
            Section {
                ShortLongRatioCard(exposure: snapshot.sideExposure)
            }
        }

        Section {
            PortfolioChartCard(title: "Account Value", period: $model.chartPeriod,
                               points: model.accountValueChart(model.chartPeriod), kind: .accountValue)
                .listRowInsets(EdgeInsets(top: 8, leading: 12, bottom: 8, trailing: 12))
                .listRowBackground(Color.clear)
            PortfolioChartCard(title: "PnL", period: $model.chartPeriod,
                               points: model.pnlChart(model.chartPeriod), kind: .pnl)
                .listRowInsets(EdgeInsets(top: 8, leading: 12, bottom: 8, trailing: 12))
                .listRowBackground(Color.clear)
        }

        let openPositions = snapshot.perps.openPositions
        if canTrade && (!openPositions.isEmpty || !snapshot.openOrders.isEmpty) {
            Section {
                Button(role: .destructive) {
                    tradeContext = .closeAll(positions: openPositions, orders: snapshot.openOrders)
                } label: {
                    Text("Close all positions & orders")
                        .font(.body.weight(.semibold))
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(.red)
                .listRowInsets(EdgeInsets(top: 8, leading: 12, bottom: 8, trailing: 12))
                .listRowBackground(Color.clear)
            } footer: {
                Text("Markets out every open position and cancels every resting order.")
            }
        }

        if !snapshot.perps.openPositions.isEmpty {
            Section("Open Positions") {
                ForEach(snapshot.perps.openPositions, id: \.coin) { position in
                    PositionRow(
                        position: position,
                        markPrice: snapshot.mark(for: position.coin)
                    )
                    .swipeActions(edge: .trailing) {
                        if canTrade {
                            Button {
                                tradeContext = .closePosition(position)
                            } label: { Label("Close", systemImage: "xmark.circle") }
                            .tint(.red)
                        }
                    }
                    .swipeActions(edge: .leading) {
                        Button {
                            priceAlertCoin = AlertCoin(coin: position.coin)
                        } label: { Label("Alert", systemImage: "bell") }
                        .tint(.indigo)
                    }
                }
            }
        }

        let spot = snapshot.spot.nonZeroBalances
        if !spot.isEmpty {
            Section("Spot Balances") {
                ForEach(spot) { balance in
                    SpotBalanceRow(balance: balance, usdValue: snapshot.usdValue(of: balance))
                        .swipeActions(edge: .trailing) {
                            if canTrade && !balance.isUSDC {
                                Button {
                                    tradeContext = .sellSpot(balance)
                                } label: { Label("Sell", systemImage: "dollarsign.arrow.circlepath") }
                                .tint(.orange)
                            }
                        }
                }
            }
        }

        if !snapshot.openOrders.isEmpty {
            Section("Open Orders") {
                ForEach(snapshot.openOrders) { order in
                    OpenOrderRow(order: order)
                        .swipeActions(edge: .trailing) {
                            if canTrade {
                                Button {
                                    tradeContext = .cancelOrder(order)
                                } label: { Label("Cancel", systemImage: "xmark") }
                                .tint(.red)
                            }
                        }
                }
            }
        }

        Section {
            LabeledContent("Address", value: wallet.shortAddress)
                .font(.footnote)
            if canTrade, let expiry = expiryStore.expiries[wallet.id] {
                LabeledContent("Agent key") {
                    AgentKeyBadge(expiry: expiry)
                }
                .font(.footnote)
                if expiry.source == .estimated {
                    Text("Estimated from key add date.")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            if !canTrade {
                Label("Read-only — add an agent key to trade", systemImage: "eye")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            Button(canTrade ? "Replace agent key…" : "Add agent key…") {
                editingAgentKey = true
            }
            .font(.footnote)
        }
    }

    /// Mirrors `content(_:)` section for section — summary, charts, then
    /// positions — so the loaded screen fills the placeholder in place instead
    /// of shoving it down the page. The summary and chart placeholders are the
    /// real components in their loading state, not copies of them.
    @ViewBuilder
    private var loadingSkeleton: some View {
        Section {
            AccountSummaryCard()
                .listRowInsets(EdgeInsets(top: 8, leading: 12, bottom: 8, trailing: 12))
                .listRowBackground(Color.clear)
        }

        Section {
            ForEach(["Account Value", "PnL"], id: \.self) { title in
                PortfolioChartCard.Placeholder(title: title)
                    .listRowInsets(EdgeInsets(top: 8, leading: 12, bottom: 8, trailing: 12))
                    .listRowBackground(Color.clear)
            }
        }

        Section("Open Positions") {
            ForEach(0..<2, id: \.self) { _ in skeletonRow }
        }
    }

    private var skeletonRow: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("COIN").font(.headline)
                Spacer()
                Text("+$0,000.00").font(.subheadline.weight(.semibold)).monospacedDigit()
            }
            HStack(spacing: 16) {
                Text("0.0000")
                Text("$00,000")
                Text("$00,000")
            }
            .font(.caption)
        }
        .padding(.vertical, 4)
        .redacted(reason: .placeholder)
        .accessibilityLabel("Loading position")
    }

    private func errorRow(_ message: String) -> some View {
        VStack(spacing: 12) {
            Label("Couldn't load wallet", systemImage: "wifi.exclamationmark")
                .font(.headline)
            Text(message).font(.caption).foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button("Retry") { Task { await model.load(session: settings.session) } }
                .buttonStyle(.bordered)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .listRowBackground(Color.clear)
    }
}
