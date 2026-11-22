import SwiftUI

/// Amount-first order ticket: one large dollar figure driven by a custom
/// keypad, with Long and Short as the two final actions. Both lead to the
/// standard trade confirmation, so nothing is sent without review and Face ID.
struct OrderTicketView: View {
    let wallet: Wallet
    let onCompleted: () -> Void

    @EnvironmentObject private var settings: AppSettings
    @Environment(\.dismiss) private var dismiss
    @StateObject private var model: OrderTicketModel
    @State private var confirming: TradeContext?
    @State private var traded = false
    @State private var pickingCoin = false

    init(wallet: Wallet, coin: String, available: Double, positions: [Position], onCompleted: @escaping () -> Void) {
        self.wallet = wallet
        self.onCompleted = onCompleted
        _model = StateObject(wrappedValue: OrderTicketModel(coin: coin, available: available, positions: positions))
    }

    /// "Max" holds back 2% so the exchange fee never pushes margin past what's available.
    private static let shares: [(String, Double)] = [("10%", 0.1), ("25%", 0.25), ("50%", 0.5), ("Max", 0.98)]
    private static let takeProfitMoves: [Double] = [0.02, 0.05, 0.1, 0.25]
    private static let stopLossMoves: [Double] = [0.01, 0.02, 0.05, 0.1]

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Picker("Order type", selection: $model.isLimit) {
                    Text("Market").tag(false)
                    Text("Limit").tag(true)
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)

                Spacer(minLength: 12)
                figures
                Spacer(minLength: 12)

                shareChips.padding(.horizontal)
                optionsRow.padding(.horizontal).padding(.top, 12)

                Text(model.problem ?? " ")
                    .font(.footnote)
                    .foregroundStyle(.cautionText)
                    .frame(minHeight: 20)
                    .padding(.top, 8)

                keypad
                sideButtons.padding()
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .principal) {
                    Button { pickingCoin = true } label: {
                        HStack(spacing: 4) {
                            Text(model.coin).font(.headline)
                            Image(systemName: "chevron.down").font(.caption.weight(.semibold))
                        }
                    }
                    .tint(.primary)
                    .accessibilityLabel("Market \(model.coin). Change market")
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Text(model.mark.map(Format.price) ?? "")
                        .font(.footnote)
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                }
            }
            .navigationDestination(isPresented: $pickingCoin) {
                CoinPickerView(coins: model.coins, selected: model.coin) {
                    model.select($0)
                    pickingCoin = false
                }
            }
        }
        .task(id: model.coin) { await model.track(session: settings.session) }
        .sheet(item: $confirming, onDismiss: finishIfTraded) { context in
            TradeConfirmationView(wallet: wallet, context: context, session: settings.session) {
                traded = true
            }
        }
    }

    // MARK: Figures

    private var figures: some View {
        VStack(spacing: 6) {
            Button { model.focus = .amount } label: {
                Text(dollars(model.amount.text))
                    .font(.system(size: 52, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .minimumScaleFactor(0.5)
                    .lineLimit(1)
                    .foregroundStyle(model.focus == .amount ? .primary : .secondary)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Amount \(dollars(model.amount.text))")

            Text(summary)
                .font(.footnote.monospacedDigit())
                .foregroundStyle(.secondary)

            if model.isLimit {
                Button { model.focus = .price } label: {
                    HStack(spacing: 6) {
                        Text("Limit").foregroundStyle(.secondary)
                        Text(model.limitPrice.text.isEmpty ? "0" : model.limitPrice.text)
                            .monospacedDigit()
                            .foregroundStyle(model.focus == .price ? .primary : .secondary)
                    }
                    .font(.title3.weight(.semibold))
                    .padding(.vertical, 4)
                    .padding(.horizontal, 10)
                    .overlay {
                        RoundedRectangle(cornerRadius: Theme.surfaceRadius)
                            .stroke(model.focus == .price ? Color.accentColor : .clear)
                    }
                }
                .buttonStyle(.plain)
                .padding(.top, 6)
            }
        }
        .padding(.horizontal)
    }

    private var summary: String {
        let size = model.size.map { "\(Format.number($0, fractionDigits: 4)) \(model.coin)" } ?? "–"
        return "\(size) · \(model.leverage)x · margin \(Format.usd(model.notional / Double(model.leverage)))"
    }

    /// Groups the whole-dollar part as it's typed, keeping whatever fraction
    /// the keypad holds so far ("1234." reads "$1,234.").
    private func dollars(_ text: String) -> String {
        guard !text.isEmpty else { return "$0" }
        let parts = text.split(separator: ".", omittingEmptySubsequences: false)
        let whole = Format.number(Double(parts[0]) ?? 0, fractionDigits: 0)
        return "$" + whole + (parts.count > 1 ? "." + parts[1] : "")
    }

    // MARK: Controls

    private var shareChips: some View {
        HStack(spacing: 8) {
            ForEach(Self.shares, id: \.0) { label, share in
                Button(label) { model.fill(share) }
                    .buttonStyle(.bordered)
                    .font(.footnote.monospacedDigit())
                    .frame(maxWidth: .infinity)
            }
        }
    }

    private var optionsRow: some View {
        HStack {
            Menu {
                Picker("Leverage", selection: $model.leverage) {
                    ForEach(leverageChoices, id: \.self) { Text("\($0)x").tag($0) }
                }
            } label: {
                option("Leverage", "\(model.leverage)x")
            }
            Spacer()
            moveMenu("TP", moves: Self.takeProfitMoves, sign: "+", selection: $model.takeProfitMove)
            Spacer()
            moveMenu("SL", moves: Self.stopLossMoves, sign: "−", selection: $model.stopLossMove)
        }
        .font(.subheadline)
    }

    private var leverageChoices: [Int] {
        let stops = [1, 2, 3, 5, 10, 20, 25, 40, 50].filter { $0 < model.maxLeverage }
        return stops + [model.maxLeverage]
    }

    /// TP/SL as a price move from entry. Side-agnostic on purpose: the side
    /// isn't chosen until Long or Short, and the confirmation shows exact prices.
    private func moveMenu(_ title: String, moves: [Double], sign: String, selection: Binding<Double?>) -> some View {
        Menu {
            Picker(title, selection: selection) {
                Text("Off").tag(Double?.none)
                ForEach(moves, id: \.self) { move in
                    Text("\(sign)\(Format.percent(move * 100, fractionDigits: 0))").tag(Double?.some(move))
                }
            }
        } label: {
            option(title, selection.wrappedValue.map { "\(sign)\(Format.percent($0 * 100, fractionDigits: 0))" } ?? "Off")
        }
    }

    private func option(_ title: String, _ value: String) -> some View {
        HStack(spacing: 4) {
            Text(title).foregroundStyle(.secondary)
            Text(value).monospacedDigit().foregroundStyle(.primary)
        }
    }

    private var keypad: some View {
        let keys: [KeypadEntry.Key] = (1...9).map { .digit($0) } + [.point, .digit(0), .delete]
        return LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 0) {
            ForEach(keys, id: \.self) { key in
                Button { model.press(key) } label: {
                    keyLabel(key)
                        .font(.title2.monospacedDigit())
                        .frame(maxWidth: .infinity, minHeight: 52)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .sensoryFeedback(.selection, trigger: model.focus == .amount ? model.amount : model.limitPrice)
        .padding(.horizontal)
    }

    @ViewBuilder
    private func keyLabel(_ key: KeypadEntry.Key) -> some View {
        switch key {
        case .digit(let d): Text(String(d))
        case .point: Text(".")
        case .delete: Image(systemName: "delete.left").accessibilityLabel("Delete")
        }
    }

    private var sideButtons: some View {
        HStack(spacing: 10) {
            sideButton(isLong: true)
            sideButton(isLong: false)
        }
    }

    private func sideButton(isLong: Bool) -> some View {
        Button {
            confirming = .openPosition(model.ticket(isLong: isLong))
        } label: {
            Text(isLong ? "Long" : "Short")
                .font(.body.weight(.semibold))
                .frame(maxWidth: .infinity, minHeight: 34)
        }
        .buttonStyle(.borderedProminent)
        .tint(isLong ? .gain : .loss)
        .disabled(model.problem != nil)
    }

    private func finishIfTraded() {
        guard traded else { return }
        onCompleted()
        dismiss()
    }
}

struct CoinPickerView: View {
    let coins: [String]
    let selected: String
    let onSelect: (String) -> Void

    @State private var query = ""

    private var filtered: [String] {
        query.isEmpty ? coins : coins.filter { $0.localizedCaseInsensitiveContains(query) }
    }

    var body: some View {
        List(filtered, id: \.self) { coin in
            Button { onSelect(coin) } label: {
                HStack {
                    Text(coin).foregroundStyle(.primary)
                    Spacer()
                    if coin == selected { Image(systemName: "checkmark") }
                }
            }
        }
        .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always))
        .navigationTitle("Market")
        .navigationBarTitleDisplayMode(.inline)
        .overlay { if coins.isEmpty { Text("Loading markets…").foregroundStyle(.secondary) } }
    }
}
