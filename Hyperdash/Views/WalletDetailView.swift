import SwiftUI

struct WalletDetailView: View {
    let wallet: Wallet

    @EnvironmentObject private var settings: AppSettings
    @EnvironmentObject private var store: WalletStore
    @StateObject private var model: WalletDetailViewModel
    @State private var tradeContext: TradeContext?
    @State private var priceAlertCoin: AlertCoin?

    private struct AlertCoin: Identifiable { let coin: String; var id: String { coin } }

    init(wallet: Wallet) {
        self.wallet = wallet
        _model = StateObject(wrappedValue: WalletDetailViewModel(wallet: wallet))
    }

    private var canTrade: Bool { store.hasAgentKey(wallet) }

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
        .refreshable { await model.load(session: settings.session) }
        .task(id: settings.network) { await model.load(session: settings.session) }
        .sheet(item: $tradeContext) { context in
            TradeConfirmationView(wallet: wallet, context: context, session: settings.session) {
                Task { await model.load(session: settings.session) }
            }
        }
        .sheet(item: $priceAlertCoin) { item in
            AddPriceAlertView(coin: item.coin)
        }
    }

    @ViewBuilder
    private func content(_ snapshot: WalletSnapshot) -> some View {
        Section {
            VaultStatGrid(snapshot: snapshot)
                .listRowInsets(EdgeInsets(top: 8, leading: 12, bottom: 8, trailing: 12))
                .listRowBackground(Color.clear)
        }

        if !snapshot.perps.openPositions.isEmpty {
            Section {
                ShortLongRatioCard(exposure: snapshot.sideExposure)
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
            if !canTrade {
                Label("Read-only — add an agent key to trade", systemImage: "eye")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder
    private var loadingSkeleton: some View {
        Section {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Total Value").font(.caption).foregroundStyle(.secondary)
                    Text("$000,000.00")
                        .font(.system(.largeTitle, design: .rounded).weight(.bold))
                        .monospacedDigit()
                }
                Divider()
                HStack {
                    ForEach(["Perps Equity", "Spot Value", "Withdrawable"], id: \.self) { title in
                        VStack(alignment: .leading, spacing: 2) {
                            Text(title).font(.caption2).foregroundStyle(.secondary)
                            Text("$0,000.00").font(.subheadline.weight(.semibold)).monospacedDigit()
                        }
                        Spacer(minLength: 8)
                    }
                }
            }
            .padding(.vertical, 4)
            .redacted(reason: .placeholder)
            .accessibilityLabel("Loading account summary")
        }

        Section("Perp Positions") {
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
