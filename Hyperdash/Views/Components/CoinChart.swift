import SwiftUI
import Charts

/// A coin's price history as candles or a line of closes. Two looks:
/// `.full` is the standalone chart (time labels, high/low, scrubbing);
/// `.backdrop` is bare marks with no axes or gestures, to sit behind the
/// TP/SL ladder, which supplies its own `yDomain` so both share one scale.
struct CoinChart: View {
    enum Chrome { case full, backdrop }

    let candles: [Candle]
    let style: ChartStyle
    var yDomain: ClosedRange<Double>?
    var chrome: Chrome = .full
    @Binding var scrubbed: Candle?

    init(candles: [Candle], style: ChartStyle, yDomain: ClosedRange<Double>? = nil,
         chrome: Chrome = .full, scrubbed: Binding<Candle?> = .constant(nil)) {
        self.candles = candles
        self.style = style
        self.yDomain = yDomain
        self.chrome = chrome
        _scrubbed = scrubbed
    }

    private var color: Color {
        guard let change = PriceChange(over: candles)?.absolute, change != 0 else { return .secondary }
        return .directionText(isPositive: change > 0)
    }

    var body: some View {
        let frame = Frame(candles: candles, style: style, fixedDomain: yDomain)
        let chart = Chart {
            if style == .candles {
                ForEach(candles) { candleMarks($0, in: frame) }
            } else {
                lineMarks(in: frame)
            }
            if chrome == .full { annotations(in: frame) }
        }
        .chartXScale(domain: frame.xDomain)
        .chartYScale(domain: frame.yDomain)
        .chartPlotStyle { $0.clipped() }
        .chartYAxis(.hidden)
        .chartLegend(.hidden)

        switch chrome {
        case .backdrop:
            chart
                .chartXAxis(.hidden)
                .allowsHitTesting(false)
                .accessibilityHidden(true)
        case .full:
            chart
                .chartXAxis {
                    // Built explicitly: a bare `AxisValueLabel()` ignores `.foregroundStyle`.
                    AxisMarks(values: .automatic(desiredCount: 4)) { value in
                        AxisValueLabel {
                            if let date = value.as(Date.self) {
                                Text(date, format: frame.axisFormat)
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
                .chartOverlay { proxy in scrubOverlay(proxy) }
                .sensoryFeedback(.selection, trigger: scrubbed?.openTime)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(Text("Price chart"))
                .accessibilityValue(Text(verbatim: accessibilitySummary))
        }
    }

    // MARK: - Marks

    @ChartContentBuilder
    private func candleMarks(_ candle: Candle, in frame: Frame) -> some ChartContent {
        let tint = Color.directionText(isPositive: candle.isGain)
        let dim = scrubbed == nil || scrubbed?.openTime == candle.openTime ? 1.0 : 0.4
        let inset = candle.closeTime.timeIntervalSince(candle.openTime) * 0.15
        RuleMark(x: .value("Time", candle.midTime),
                 yStart: .value("Low", frame.clamped(candle.low)),
                 yEnd: .value("High", frame.clamped(candle.high)))
            .lineStyle(StrokeStyle(lineWidth: 1))
            .foregroundStyle(tint)
            .opacity(dim)
        RectangleMark(xStart: .value("Open time", candle.openTime.addingTimeInterval(inset)),
                      xEnd: .value("Close time", candle.closeTime.addingTimeInterval(-inset)),
                      yStart: .value("Body low", frame.clamped(min(candle.open, candle.close))),
                      yEnd: .value("Body high", frame.clamped(max(candle.open, candle.close))))
            .foregroundStyle(tint)
            .opacity(dim)
    }

    @ChartContentBuilder
    private func lineMarks(in frame: Frame) -> some ChartContent {
        // Where the window opened, so "up" and "down" have a reference.
        if chrome == .full, let open = candles.first?.open, frame.yDomain.contains(open) {
            RuleMark(y: .value("Open", open))
                .lineStyle(StrokeStyle(lineWidth: 1, dash: [2, 4]))
                .foregroundStyle(Color.secondary.opacity(0.5))
        }
        ForEach(candles) { candle in
            LineMark(x: .value("Time", candle.openTime), y: .value("Close", frame.clamped(candle.close)))
                .interpolationMethod(.linear)
                .lineStyle(StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
                .foregroundStyle(color)
        }
    }

    /// High and low captions plus the scrub rule. Captions ride invisible points.
    @ChartContentBuilder
    private func annotations(in frame: Frame) -> some ChartContent {
        if let high = frame.high, let low = frame.low, high.value != low.value {
            extremeLabel(high, position: .top, in: frame)
            extremeLabel(low, position: .bottom, in: frame)
        }
        if let scrubbed {
            RuleMark(x: .value("Time", style == .candles ? scrubbed.midTime : scrubbed.openTime))
                .lineStyle(StrokeStyle(lineWidth: 1))
                .foregroundStyle(Color.secondary.opacity(0.35))
            if style == .line {
                let y = frame.clamped(scrubbed.close)
                PointMark(x: .value("Time", scrubbed.openTime), y: .value("Close", y))
                    .symbolSize(169)
                    .foregroundStyle(Color(.secondarySystemGroupedBackground))
                PointMark(x: .value("Time", scrubbed.openTime), y: .value("Close", y))
                    .symbolSize(81)
                    .foregroundStyle(color)
            }
        }
    }

    @ChartContentBuilder
    private func extremeLabel(_ extreme: Frame.Extreme, position: AnnotationPosition, in frame: Frame) -> some ChartContent {
        PointMark(x: .value("Time", extreme.date), y: .value("Price", frame.clamped(extreme.value)))
            .symbolSize(1)
            .foregroundStyle(.clear)
            .annotation(position: position, spacing: 2,
                        overflowResolution: .init(x: .fit(to: .chart), y: .fit(to: .chart))) {
                Text(Format.price(extreme.value))
                    .font(.caption2)
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
    }

    // MARK: - Scrubbing

    private func scrubOverlay(_ proxy: ChartProxy) -> some View {
        GeometryReader { geo in
            Rectangle().fill(.clear).contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { drag in
                            guard let plotFrame = proxy.plotFrame else { return }
                            let x = drag.location.x - geo[plotFrame].origin.x
                            guard let date: Date = proxy.value(atX: x) else { return }
                            scrubbed = candles.min {
                                abs($0.openTime.timeIntervalSince(date)) < abs($1.openTime.timeIntervalSince(date))
                            }
                        }
                        .onEnded { _ in scrubbed = nil }
                )
        }
    }

    private var accessibilitySummary: String {
        guard let last = candles.last else { return "No data" }
        let current = Format.price(last.close)
        guard let change = PriceChange(over: candles) else { return current }
        return "\(current), \(Format.signedPrice(change.absolute)) over the period"
    }
}

// MARK: - Plot geometry

private extension CoinChart {
    struct Frame {
        struct Extreme {
            let date: Date
            let value: Double
        }

        let xDomain: ClosedRange<Date>
        let yDomain: ClosedRange<Double>
        let high: Extreme?
        let low: Extreme?

        init(candles: [Candle], style: ChartStyle, fixedDomain: ClosedRange<Double>?) {
            let highs = candles.map { Extreme(date: style == .candles ? $0.midTime : $0.openTime,
                                              value: style == .candles ? $0.high : $0.close) }
            let lows = candles.map { Extreme(date: style == .candles ? $0.midTime : $0.openTime,
                                             value: style == .candles ? $0.low : $0.close) }
            high = highs.max { $0.value < $1.value }
            low = lows.min { $0.value < $1.value }

            if let first = candles.first?.openTime, let last = candles.last?.closeTime, first < last {
                xDomain = first...last
            } else {
                let now = candles.first?.openTime ?? Date()
                xDomain = now...now.addingTimeInterval(1)
            }

            if let fixedDomain, fixedDomain.lowerBound < fixedDomain.upperBound {
                yDomain = fixedDomain
            } else if let lo = low?.value, let hi = high?.value {
                let pad = hi > lo ? (hi - lo) * 0.12 : max(abs(hi) * 0.01, 1e-9)
                yDomain = (lo - pad)...(hi + pad)
            } else {
                yDomain = 0...1
            }
        }

        /// Marks plot clamped values: a point outside the framed domain would be
        /// sliced flat by the plot's clip. Riding the edge reads as "off the chart".
        func clamped(_ value: Double) -> Double {
            min(max(value, yDomain.lowerBound), yDomain.upperBound)
        }

        var axisFormat: Date.FormatStyle {
            let span = xDomain.upperBound.timeIntervalSince(xDomain.lowerBound)
            switch span {
            case ..<(2 * 86_400): return .dateTime.hour()
            case ..<(8 * 86_400): return .dateTime.weekday(.abbreviated)
            case ..<(120 * 86_400): return .dateTime.month(.abbreviated).day()
            default: return .dateTime.month(.abbreviated)
            }
        }
    }
}

extension CoinChart {
    /// What a scrubbed candle's timestamp reads as under the headline.
    static func scrubDateFormat(for range: CandleRange) -> Date.FormatStyle {
        switch range {
        case .day: return .dateTime.hour().minute()
        case .week: return .dateTime.weekday(.abbreviated).hour().minute()
        case .month: return .dateTime.month(.abbreviated).day().hour()
        case .quarter, .year: return .dateTime.month(.abbreviated).day().year()
        }
    }

    /// Stands in at the plot's size while candles load: static, never animated.
    struct Placeholder: View {
        var body: some View {
            RoundedRectangle(cornerRadius: Theme.surfaceRadius)
                .fill(Color.secondary.opacity(0.12))
                .redacted(reason: .placeholder)
                .accessibilityHidden(true)
        }
    }
}

// MARK: - Controls

protocol ChartRangeOption: Identifiable, Hashable {
    var label: String { get }
    var accessibilityLabel: String { get }
}

extension CandleRange: ChartRangeOption {}

/// Range buttons as plain text under a plot; the chosen one is filled.
struct ChartRangePicker<Option: ChartRangeOption>: View {
    @Binding var selection: Option
    let options: [Option]

    var body: some View {
        HStack(spacing: 4) {
            ForEach(options) { option in
                Button { selection = option } label: {
                    Text(option.label)
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(option == selection ? Color.primary : Color.secondary)
                        .frame(maxWidth: .infinity, minHeight: 32)
                        .background(option == selection ? Color.secondary.opacity(0.18) : Color.clear,
                                    in: RoundedRectangle(cornerRadius: 8))
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(option.accessibilityLabel)
                .accessibilityAddTraits(option == selection ? .isSelected : [])
            }
        }
        .sensoryFeedback(.selection, trigger: selection)
    }
}

/// Candles or Line. The choice is stored once and shared by every coin chart.
struct ChartStyleToggle: View {
    @AppStorage(AppSettings.coinChartStyleKey) private var style: ChartStyle = .standard

    var body: some View {
        HStack(spacing: 0) {
            ForEach(ChartStyle.allCases) { option in
                Button { style = option } label: {
                    Text(option.label)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(option == style ? Color.primary : Color.secondary)
                        .padding(.horizontal, 8)
                        .frame(minHeight: 28)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(option == style ? .isSelected : [])
            }
        }
        .sensoryFeedback(.selection, trigger: style)
    }
}

/// Something that failed to load: one quiet line and a way back.
struct ChartRetryRow: View {
    var message = "Couldn't load the chart."
    let retry: () -> Void

    var body: some View {
        HStack {
            Text(message)
                .foregroundStyle(.secondary)
            Spacer()
            Button("Retry", action: retry)
        }
        .font(.caption)
    }
}
