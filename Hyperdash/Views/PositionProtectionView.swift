import SwiftUI

/// TP/SL for an open position, set on a price ladder: liquidation, entry,
/// mark and both triggers drawn to scale, with the triggers dragged into
/// place. Review hands off to the standard confirmation.
struct PositionProtectionView: View {
    let wallet: Wallet
    let position: Position
    let mark: Double
    /// Trigger orders already guarding the position; replaced on submit.
    let existing: [OpenOrder]
    let onCompleted: () -> Void

    @EnvironmentObject private var settings: AppSettings
    @Environment(\.dismiss) private var dismiss
    @State private var takeProfit: Double?
    @State private var stopLoss: Double?
    @State private var scale: LadderScale
    @State private var editing: Protection.Kind?
    @State private var draft = ""
    @State private var confirming: TradeContext?
    @State private var traded = false
    @StateObject private var chart = CoinChartModel()
    @State private var range: CandleRange = .day
    @State private var chartAttempt = 0
    /// Low and high of the loaded candles, kept inside the ladder's scale.
    @State private var chartExtent: [Double] = []
    @State private var dragging = false
    @AppStorage(AppSettings.coinChartStyleKey) private var chartStyle: ChartStyle = .standard

    private let initialTakeProfit: Double?
    private let initialStopLoss: Double?

    init(wallet: Wallet, position: Position, mark: Double, orders: [OpenOrder], onCompleted: @escaping () -> Void) {
        self.wallet = wallet
        self.position = position
        self.mark = mark
        self.onCompleted = onCompleted
        let existing = Protection.existingTriggers(for: position.coin, in: orders)
        self.existing = existing
        let levels = existing.compactMap(\.protectionLevel)
        initialTakeProfit = levels.first { $0.kind == .takeProfit }?.price
        initialStopLoss = levels.first { $0.kind == .stopLoss }?.price
        _takeProfit = State(initialValue: initialTakeProfit)
        _stopLoss = State(initialValue: initialStopLoss)
        _scale = State(initialValue: Self.scale(position: position, mark: mark,
                                                levels: [initialTakeProfit, initialStopLoss]))
    }

    private var hasChanges: Bool {
        takeProfit != initialTakeProfit || stopLoss != initialStopLoss
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    chartControls
                    ZStack(alignment: .topLeading) {
                        chartBackdrop
                        PriceLadder(
                            scale: scale, mark: mark, entry: position.entryPrice,
                            liquidation: position.liquidationPrice, isLong: position.isLong,
                            takeProfit: $takeProfit, stopLoss: $stopLoss,
                            onDragStarted: { dragging = true },
                            onDragEnded: rescale
                        )
                    }
                    .listRowInsets(EdgeInsets(top: 12, leading: 8, bottom: 12, trailing: 12))
                }

                Section {
                    levelRow(.takeProfit, price: takeProfit)
                    levelRow(.stopLoss, price: stopLoss)
                } footer: {
                    if let warning { Text(warning).foregroundStyle(.cautionText) }
                }
            }
            .task(id: chartRequest) { await loadChart() }
            .navigationTitle("\(position.coin) \(position.directionLabel)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .safeAreaInset(edge: .bottom) {
                Button {
                    confirming = .setProtection(position, takeProfit: takeProfit, stopLoss: stopLoss, replacing: existing)
                } label: {
                    Text("Review").font(.body.weight(.semibold)).frame(maxWidth: .infinity, minHeight: 34)
                }
                .buttonStyle(.borderedProminent)
                .disabled(!hasChanges)
                .padding()
                .background(.bar)
            }
            .alert(editing == .takeProfit ? "Take profit" : "Stop loss",
                   isPresented: Binding(get: { editing != nil }, set: { if !$0 { editing = nil } })) {
                TextField("Trigger price", text: $draft).keyboardType(.decimalPad)
                Button("Cancel", role: .cancel) {}
                Button("Set", action: commitDraft)
            } message: {
                Text("Must be \(validSideDescription(editing ?? .takeProfit)) the mark of \(Format.price(mark)).")
            }
        }
        .sheet(item: $confirming, onDismiss: finishIfTraded) { context in
            TradeConfirmationView(wallet: wallet, context: context, session: settings.session) {
                traded = true
            }
        }
    }

    // MARK: Price chart

    private var chartRequest: CoinChartModel.Request {
        .init(coin: position.coin, range: range, network: settings.network, attempt: chartAttempt)
    }

    /// The previous candles stay up while a new range loads. Once they land the
    /// scale refits around them, unless a drag is in flight: that drag's end refits.
    private func loadChart() async {
        await chart.load(chartRequest, session: settings.session, keepingPrevious: true)
        guard !Task.isCancelled else { return }
        let candles = chart.candles.value ?? []
        chartExtent = [candles.map(\.low).min(), candles.map(\.high).max()].compactMap { $0 }
        if !dragging { refit() }
    }

    private var chartControls: some View {
        VStack(spacing: 4) {
            HStack {
                ChartRangePicker(selection: $range, options: CandleRange.ladder)
                ChartStyleToggle()
            }
            if case .failed = chart.candles {
                ChartRetryRow { chartAttempt += 1 }
            }
        }
    }

    /// Price history drawn on the ladder's own scale, dimmed so the level lines
    /// and handles stay the most prominent thing on the screen.
    @ViewBuilder
    private var chartBackdrop: some View {
        switch chart.candles {
        case .loading:
            ChartPlaceholder()
                .frame(height: PriceLadder.height)
                .padding(.leading, PriceLadder.axisInset)
        case .loaded(let candles) where !candles.isEmpty:
            CoinChart(candles: candles, style: chartStyle, yDomain: scale.low...scale.high, chrome: .backdrop)
                .frame(height: PriceLadder.height)
                .padding(.leading, PriceLadder.axisInset)
                .opacity(0.45)
        default:
            EmptyView()
        }
    }

    // MARK: Rows

    private func levelRow(_ kind: Protection.Kind, price: Double?) -> some View {
        let title = kind == .takeProfit ? "Take profit" : "Stop loss"
        return HStack {
            Text(title)
            Spacer()
            if let price {
                Button {
                    draft = Format.number(price, fractionDigits: price < 100 ? 4 : 1)
                        .replacingOccurrences(of: ",", with: "")
                    editing = kind
                } label: {
                    VStack(alignment: .trailing, spacing: 1) {
                        Text(Format.price(price)).monospacedDigit().foregroundStyle(.primary)
                        if let outcome = outcome(at: price) {
                            Text(outcome.text)
                                .font(.caption2.monospacedDigit())
                                .foregroundStyle(.directionText(isPositive: outcome.pnl >= 0))
                                .privacySensitive()
                        }
                    }
                }
                Button { set(kind, nil) } label: {
                    Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary)
                }
                .buttonStyle(.borderless)
                .accessibilityLabel("Remove \(title.lowercased())")
            } else {
                Button("Add") { set(kind, defaultPrice(kind)) }
            }
        }
    }

    private func outcome(at price: Double) -> (pnl: Double, text: String)? {
        guard let entry = position.entryPrice else { return nil }
        let pnl = Protection.pnl(at: price, entry: entry, signedSize: position.size)
        let margin = position.marginUsedValue
        let roe = margin > 0 ? "  \(Format.signedPercent(pnl / margin * 100, fractionDigits: 0))" : ""
        return (pnl, Format.signedUSD(pnl) + roe)
    }

    private var warning: String? {
        guard let stopLoss, let liq = position.liquidationPrice, liq > 0 else { return nil }
        let pastLiquidation = position.isLong ? stopLoss <= liq : stopLoss >= liq
        return pastLiquidation ? "The stop is past liquidation, so liquidation would hit first." : nil
    }

    // MARK: Editing

    private func set(_ kind: Protection.Kind, _ price: Double?) {
        switch kind {
        case .takeProfit: takeProfit = price
        case .stopLoss: stopLoss = price
        }
        rescale()
    }

    /// 5% into profit or 3% into loss from the mark; a stop never starts past
    /// liquidation.
    private func defaultPrice(_ kind: Protection.Kind) -> Double {
        let move = kind == .takeProfit ? 0.05 : 0.03
        var price = Protection.price(movingBy: move, from: mark, kind: kind, isLong: position.isLong)
        if kind == .stopLoss, let liq = position.liquidationPrice, liq > 0 {
            price = position.isLong ? max(price, (mark + liq) / 2) : min(price, (mark + liq) / 2)
        }
        return PriceLadder.tidy(price)
    }

    private func commitDraft() {
        guard let kind = editing, let price = Double(draft.replacingOccurrences(of: ",", with: ".")),
              Protection.isValid(price, kind: kind, isLong: position.isLong, reference: mark) else { return }
        set(kind, price)
    }

    private func validSideDescription(_ kind: Protection.Kind) -> String {
        Protection.isValid(mark * 2, kind: kind, isLong: position.isLong, reference: mark) ? "above" : "below"
    }

    private func rescale() {
        dragging = false
        refit()
    }

    private func refit() {
        scale = Self.scale(position: position, mark: mark, levels: [takeProfit, stopLoss], extent: chartExtent)
    }

    private static func scale(position: Position, mark: Double, levels: [Double?], extent: [Double] = []) -> LadderScale {
        LadderScale(levels: (levels + [position.entryPrice, position.liquidationPrice]).compactMap { $0 } + extent, mark: mark)
    }

    private func finishIfTraded() {
        guard traded else { return }
        onCompleted()
        dismiss()
    }
}

/// The vertical price axis. Static lines for liquidation, entry and mark;
/// draggable handles for the triggers, each held to its valid side of the mark.
/// The scale stays fixed during a drag and is refit when it ends, so pulling a
/// handle to the edge widens the range for the next drag.
struct PriceLadder: View {
    let scale: LadderScale
    let mark: Double
    let entry: Double?
    let liquidation: Double?
    let isLong: Bool
    @Binding var takeProfit: Double?
    @Binding var stopLoss: Double?
    var onDragStarted: () -> Void = {}
    let onDragEnded: () -> Void

    static let height: CGFloat = 320
    private static let labelWidth: CGFloat = 44
    private static let rowHeight: CGFloat = 24
    /// Where the axis rule sits: the chart behind the ladder starts here.
    static let axisInset: CGFloat = labelWidth + 6

    /// Rounds to four significant figures so a drag lands on readable prices.
    static func tidy(_ price: Double) -> Double {
        guard price > 0 else { return price }
        let step = pow(10, floor(log10(price)) - 3)
        return (price / step).rounded() * step
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            zone(to: takeProfit, tint: .gain)
            zone(to: stopLoss, tint: .loss)
            Rectangle()
                .fill(.quaternary)
                .frame(width: 2, height: Self.height)
                .offset(x: Self.axisInset)

            if let liquidation, liquidation > 0 {
                line("Liq.", price: liquidation, tint: .cautionText, dashed: true)
            }
            if let entry { line("Entry", price: entry, tint: .secondary, dashed: true) }
            line("Mark", price: mark, tint: .primary, dashed: false)

            if takeProfit != nil { handle(.takeProfit, binding: $takeProfit, label: "TP", tint: .gainText) }
            if stopLoss != nil { handle(.stopLoss, binding: $stopLoss, label: "SL", tint: .lossText) }
        }
        .frame(maxWidth: .infinity, minHeight: Self.height, maxHeight: Self.height, alignment: .topLeading)
        .coordinateSpace(name: "ladder")
        .sensoryFeedback(.impact(weight: .light), trigger: scale)
    }

    private func y(_ price: Double) -> CGFloat {
        scale.position(of: price) * Self.height
    }

    /// Faint band between the mark and a trigger: what the move is worth.
    @ViewBuilder
    private func zone(to price: Double?, tint: Color) -> some View {
        if let price {
            let top = min(y(price), y(mark))
            Rectangle()
                .fill(tint.opacity(0.10))
                .frame(height: abs(y(price) - y(mark)))
                .padding(.leading, Self.labelWidth + 7)
                .offset(y: top)
        }
    }

    private func line(_ label: String, price: Double, tint: some ShapeStyle, dashed: Bool) -> some View {
        row(label: label, price: price, tint: tint, dashed: dashed, knob: false)
            .accessibilityElement(children: .combine)
    }

    private func row(label: String, price: Double, tint: some ShapeStyle, dashed: Bool, knob: Bool) -> some View {
        HStack(spacing: 6) {
            Text(label)
                .font(.caption.weight(knob ? .semibold : .regular))
                .frame(width: Self.labelWidth, alignment: .trailing)
            Circle()
                .frame(width: knob ? 16 : 0, height: knob ? 16 : 0)
                .frame(width: 14)
            Rectangle()
                .stroke(style: StrokeStyle(lineWidth: 1, dash: dashed ? [4, 3] : []))
                .frame(height: 1)
            Text(Format.price(price))
                .font(.caption.monospacedDigit())
                .privacySensitive()
        }
        .foregroundStyle(tint)
        .frame(height: Self.rowHeight)
        .offset(y: y(price) - Self.rowHeight / 2)
    }

    private func handle(_ kind: Protection.Kind, binding: Binding<Double?>, label: String, tint: Color) -> some View {
        let price = binding.wrappedValue ?? mark
        return row(label: label, price: price, tint: tint, dashed: true, knob: true)
            .contentShape(Rectangle())
            .highPriorityGesture(
                DragGesture(minimumDistance: 0, coordinateSpace: .named("ladder"))
                    .onChanged { drag in
                        onDragStarted()
                        binding.wrappedValue = clamped(scale.price(at: drag.location.y / Self.height), kind: kind)
                    }
                    .onEnded { _ in onDragEnded() }
            )
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(kind == .takeProfit ? "Take profit" : "Stop loss")
            .accessibilityValue(Format.price(price))
            .accessibilityAdjustableAction { direction in
                let step = direction == .increment ? 1.005 : 0.995
                binding.wrappedValue = clamped(price * step, kind: kind)
                onDragEnded()
            }
    }

    /// Holds a trigger on its valid side of the mark, a hair away from it, so
    /// it can never be placed where it would fire at once.
    private func clamped(_ price: Double, kind: Protection.Kind) -> Double {
        let tidied = Self.tidy(price)
        if Protection.isValid(tidied, kind: kind, isLong: isLong, reference: mark) { return tidied }
        return Protection.price(movingBy: 0.001, from: mark, kind: kind, isLong: isLong)
    }
}
