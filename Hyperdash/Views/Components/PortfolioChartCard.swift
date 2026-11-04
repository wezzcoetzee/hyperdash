import SwiftUI
import Charts

/// A portfolio series as a Stocks-style card: a headline that follows the
/// finger, a quiet plot, and a text range row. PnL can also be drawn as bars.
struct PortfolioChartCard: View {
    let title: String
    @Binding var period: PortfolioPeriod
    let points: [PortfolioPoint]
    var kind: Kind = .accountValue

    enum Kind { case accountValue, pnl }

    @AppStorage(AppSettings.pnlChartStyleKey) private var pnlStyle: PnLChartStyle = .line

    /// What the user is scrubbing: a reading on the line, or a bar's delta.
    @State private var selected: PortfolioPoint?
    @Environment(\.redactionReasons) private var redactionReasons

    private var style: PnLChartStyle { kind == .pnl ? pnlStyle : .line }

    var body: some View {
        let frame = Frame(points: points, kind: kind)
        let unit = PnLBuckets.unit(for: period, points: frame.points)
        let bars = style == .bars ? PnLBuckets.bars(from: frame.points, unit: unit) : []

        VStack(alignment: .leading, spacing: 12) {
            header(frame, unit: unit)

            // A redacted chart still draws its line, so privacy mode swaps in a blank plot.
            if redactionReasons.contains(.privacy) {
                RoundedRectangle(cornerRadius: Theme.surfaceRadius)
                    .fill(Color.secondary.opacity(0.12))
                    .frame(maxWidth: .infinity)
                    .frame(height: Self.plotHeight)
                    .accessibilityHidden(true)
            } else if frame.points.count < 2 {
                Text("Not enough history yet.")
                    .font(.caption).foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, minHeight: Self.plotHeight)
            } else if style == .bars {
                barChart(frame, bars: bars, unit: unit)
            } else {
                lineChart(frame)
            }

            periodPicker
        }
        .padding(12)
        .background(Color(.secondarySystemGroupedBackground),
                    in: RoundedRectangle(cornerRadius: Theme.surfaceRadius))
        .onChange(of: period) { _, _ in selected = nil }
        .onChange(of: pnlStyle) { _, _ in selected = nil }
    }

    // MARK: - Header

    /// Colour of the window as a whole: up, down, or flat.
    private func windowColor(_ frame: Frame) -> Color {
        guard let change = frame.change?.absolute, change != 0 else { return .secondary }
        return .directionText(isPositive: change > 0)
    }

    private func header(_ frame: Frame, unit: Calendar.Component) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Text(title.uppercased())
                    .font(.caption2.weight(.semibold)).tracking(0.5)
                    .foregroundStyle(.secondary)
                Spacer()
                if kind == .pnl { styleToggle }
            }

            if let value = selected?.value ?? frame.points.last?.value {
                Text(kind == .pnl ? Format.signedUSD(value) : Format.usd(value))
                    .font(.system(.title, design: .rounded).weight(.bold))
                    .monospacedDigit()
                    .foregroundStyle(kind == .pnl ? pnlHeadlineColor(value) : Color.primary)
                    .contentTransition(.numericText())
                    .privacySensitive()
            }

            if let selected {
                Text(selected.date, format: scrubDateFormat(unit))
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
            } else if let change = frame.change {
                changeLabel(change).privacySensitive()
            }
        }
    }

    private func pnlHeadlineColor(_ value: Double) -> Color {
        value == 0 ? .secondary : .directionText(isPositive: value > 0)
    }

    private func changeLabel(_ change: Frame.Change) -> some View {
        // Sign and arrow carry the meaning; colour only reinforces it.
        HStack(spacing: 4) {
            Image(systemName: change.absolute >= 0 ? "arrow.up.right" : "arrow.down.right")
                .imageScale(.small)
            Text(Format.signedUSD(change.absolute))
                .monospacedDigit()
            if let percent = change.percent {
                Text("(\(Format.signedPercent(percent, fractionDigits: 1)))")
                    .monospacedDigit()
            }
        }
        .font(.caption2.weight(.semibold))
        .foregroundStyle(change.absolute == 0
                         ? Color.secondary
                         : Color.directionText(isPositive: change.absolute > 0))
    }

    private var styleToggle: some View {
        HStack(spacing: 0) {
            ForEach(PnLChartStyle.allCases, id: \.self) { option in
                Button { pnlStyle = option } label: {
                    Image(systemName: option.symbol)
                        .imageScale(.small)
                        .foregroundStyle(option == pnlStyle ? Color.primary : Color.secondary)
                        .frame(width: 32, height: 28)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(option.accessibilityLabel)
                .accessibilityAddTraits(option == pnlStyle ? .isSelected : [])
            }
        }
        .sensoryFeedback(.selection, trigger: pnlStyle)
    }

    // MARK: - Range picker

    private var periodPicker: some View {
        HStack(spacing: 4) {
            ForEach(PortfolioPeriod.allCases) { option in
                Button { period = option } label: {
                    Text(option.label)
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(option == period ? Color.primary : Color.secondary)
                        .frame(maxWidth: .infinity, minHeight: 32)
                        .background(option == period ? Color.secondary.opacity(0.18) : Color.clear,
                                    in: RoundedRectangle(cornerRadius: 8))
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(option.accessibilityLabel)
                .accessibilityAddTraits(option == period ? .isSelected : [])
            }
        }
        .sensoryFeedback(.selection, trigger: period)
    }

    // MARK: - Charts

    fileprivate static let plotHeight: CGFloat = 172

    private func lineChart(_ frame: Frame) -> some View {
        let color = windowColor(frame)
        let high = frame.points.max { $0.value < $1.value }
        let low = frame.points.min { $0.value < $1.value }

        return plot(
            Chart {
                // Where the window opened, so "up" and "down" have a reference.
                if let open = frame.points.first?.value, frame.yDomain.contains(open) {
                    RuleMark(y: .value("Open", open))
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [2, 4]))
                        .foregroundStyle(Color.secondary.opacity(0.5))
                }

                ForEach(frame.points, id: \.date) { p in
                    LineMark(x: .value("Time", p.date), y: .value("Value", frame.clamped(p.value)))
                        .interpolationMethod(.linear)
                        .lineStyle(StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
                        .foregroundStyle(color)
                }

                if let high, let low, high.value != low.value {
                    extremeLabel(high, position: .top, in: frame)
                    extremeLabel(low, position: .bottom, in: frame)
                }

                if let selected {
                    RuleMark(x: .value("Time", selected.date))
                        .lineStyle(StrokeStyle(lineWidth: 1))
                        .foregroundStyle(Color.secondary.opacity(0.35))
                    marker(at: selected, diameter: 9, color: color, in: frame)
                } else if let last = frame.points.last {
                    marker(at: last, diameter: 7, color: color, in: frame)
                }
            },
            x: frame.xDomain, y: frame.yDomain, frame: frame
        ) { date in frame.nearestPoint(to: date) }
    }

    private func barChart(_ frame: Frame, bars: [PnLBar], unit: Calendar.Component) -> some View {
        let end = bars.last.flatMap { Calendar.current.date(byAdding: unit, value: 1, to: $0.date) }
        let xDomain = (bars.first?.date ?? frame.xDomain.lowerBound)...(end ?? frame.xDomain.upperBound)

        return plot(
            Chart {
                RuleMark(y: .value("Zero", 0))
                    .lineStyle(StrokeStyle(lineWidth: 1))
                    .foregroundStyle(Color.secondary.opacity(0.35))

                ForEach(bars, id: \.date) { bar in
                    BarMark(x: .value("Time", bar.date, unit: unit),
                            y: .value("PnL", bar.delta),
                            width: .inset(1))
                        .cornerRadius(2)
                        .foregroundStyle(bar.delta == 0 ? Color.secondary
                                                        : Color.directionText(isPositive: bar.delta > 0))
                        .opacity(selected == nil || selected?.date == bar.date ? 1 : 0.4)
                }
            },
            x: xDomain, y: Frame.barDomain(bars), frame: frame
        ) { date in
            let bar = bars.last { $0.date <= date } ?? bars.first
            return bar.map { PortfolioPoint(date: $0.date, value: $0.delta) }
        }
    }

    /// Shared plot chrome: no gridlines or y labels, a few quiet x labels, and
    /// the scrub gesture. `pick` maps a touched date to the reading to select.
    private func plot<Content: View>(
        _ chart: Content,
        x: ClosedRange<Date>,
        y: ClosedRange<Double>,
        frame: Frame,
        pick: @escaping (Date) -> PortfolioPoint?
    ) -> some View {
        chart
            .chartXScale(domain: x)
            .chartYScale(domain: y)
            .chartPlotStyle { $0.clipped() }
            .chartYAxis(.hidden)
            .chartXAxis {
                // The label has to be built explicitly: a bare `AxisValueLabel()`
                // ignores `.foregroundStyle` and renders in the system accent.
                AxisMarks(values: .automatic(desiredCount: 4)) { value in
                    AxisValueLabel {
                        if let date = value.as(Date.self) {
                            Text(date, format: axisDateFormat)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .chartOverlay { proxy in
                GeometryReader { geo in
                    Rectangle().fill(.clear).contentShape(Rectangle())
                        .gesture(
                            DragGesture(minimumDistance: 0)
                                .onChanged { drag in
                                    guard let plotFrame = proxy.plotFrame else { return }
                                    let x = drag.location.x - geo[plotFrame].origin.x
                                    guard let date: Date = proxy.value(atX: x) else { return }
                                    selected = pick(date)
                                }
                                .onEnded { _ in selected = nil }
                        )
                }
            }
            .frame(height: Self.plotHeight)
            .animation(.easeOut(duration: 0.15), value: selected)
            .sensoryFeedback(.selection, trigger: selected?.date)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text(verbatim: "\(title) over \(period.accessibilityLabel)"))
            .accessibilityValue(Text(verbatim: frame.accessibilitySummary(kind: kind)))
    }

    /// An invisible point that carries the high/low caption.
    @ChartContentBuilder
    private func extremeLabel(_ point: PortfolioPoint, position: AnnotationPosition, in frame: Frame) -> some ChartContent {
        PointMark(x: .value("Time", point.date), y: .value("Value", frame.clamped(point.value)))
            .symbolSize(1)
            .foregroundStyle(.clear)
            .annotation(position: position, spacing: 2,
                        overflowResolution: .init(x: .fit(to: .chart), y: .fit(to: .chart))) {
                Text(Format.abbreviatedUSD(point.value))
                    .font(.caption2)
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
    }

    /// A dot ringed in the card's own background so it stays readable where the
    /// line doubles back under it.
    @ChartContentBuilder
    private func marker(at point: PortfolioPoint, diameter: CGFloat, color: Color, in frame: Frame) -> some ChartContent {
        let y = frame.clamped(point.value)
        PointMark(x: .value("Time", point.date), y: .value("Value", y))
            .symbolSize((diameter + 4) * (diameter + 4))
            .foregroundStyle(Color(.secondarySystemGroupedBackground))
        PointMark(x: .value("Time", point.date), y: .value("Value", y))
            .symbolSize(diameter * diameter)
            .foregroundStyle(color)
    }

    // MARK: - Date formats

    private var axisDateFormat: Date.FormatStyle {
        switch period {
        case .day: return .dateTime.hour()
        case .week: return .dateTime.weekday(.abbreviated)
        case .month: return .dateTime.month(.abbreviated).day()
        // Two-digit year keeps repeated months apart across a multi-year history.
        case .allTime: return .dateTime.month(.abbreviated).year(.twoDigits)
        }
    }

    /// Bars name the bucket they cover; the line names the instant.
    private func scrubDateFormat(_ unit: Calendar.Component) -> Date.FormatStyle {
        if style == .bars {
            switch unit {
            case .hour: return .dateTime.month(.abbreviated).day().hour()
            case .month: return .dateTime.month(.wide).year()
            default: return .dateTime.weekday(.abbreviated).month(.abbreviated).day()
            }
        }
        switch period {
        case .day: return .dateTime.hour().minute()
        case .week: return .dateTime.weekday(.abbreviated).hour().minute()
        case .month: return .dateTime.month(.abbreviated).day()
        case .allTime: return .dateTime.month(.abbreviated).day().year()
        }
    }
}

extension PnLChartStyle {
    var symbol: String {
        switch self {
        case .line: return "chart.xyaxis.line"
        case .bars: return "chart.bar.fill"
        }
    }

    var accessibilityLabel: String {
        switch self {
        case .line: return "Line chart"
        case .bars: return "Bar chart"
        }
    }
}

// MARK: - Loading placeholder

extension PortfolioChartCard {
    /// The card's chrome at its real dimensions, for the loading state. It lives
    /// beside the card it stands in for so the two keep the same height, padding
    /// and header shape as either one changes.
    struct Placeholder: View {
        let title: String

        var body: some View {
            VStack(alignment: .leading, spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title.uppercased())
                        .font(.caption2.weight(.semibold)).tracking(0.5)
                        .foregroundStyle(.secondary)
                    Text("$00,000.00")
                        .font(.system(.title, design: .rounded).weight(.bold))
                        .monospacedDigit()
                    Text("+$0,000.00 (+0.0%)")
                        .font(.caption2.weight(.semibold))
                        .monospacedDigit()
                }

                RoundedRectangle(cornerRadius: Theme.surfaceRadius)
                    .fill(Color.secondary.opacity(0.12))
                    .frame(maxWidth: .infinity)
                    .frame(height: PortfolioChartCard.plotHeight)

                HStack(spacing: 4) {
                    ForEach(PortfolioPeriod.allCases) { p in
                        Text(p.label)
                            .font(.footnote.weight(.semibold))
                            .frame(maxWidth: .infinity, minHeight: 32)
                    }
                }
            }
            .padding(12)
            .background(Color(.secondarySystemGroupedBackground),
                        in: RoundedRectangle(cornerRadius: Theme.surfaceRadius))
            .redacted(reason: .placeholder)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text(verbatim: "Loading \(title) chart"))
        }
    }
}


// MARK: - Plot geometry

extension PortfolioChartCard {
    /// Everything the plot needs, derived once per body pass rather than
    /// recomputed by each view that asks for a domain.
    struct Frame {
        struct Change {
            let absolute: Double
            /// Only meaningful when there's a positive base to divide by, so
            /// PnL windows (which can start at or cross zero) report `nil`.
            let percent: Double?
        }

        let points: [PortfolioPoint]
        let yDomain: ClosedRange<Double>
        let xDomain: ClosedRange<Date>
        let change: Change?

        init(points raw: [PortfolioPoint], kind: Kind) {
            let points = PortfolioAggregator.trimmingFlatLeadIn(raw)
            let yDomain = Self.yDomain(points, kind: kind)
            self.points = points
            self.yDomain = yDomain
            self.xDomain = Self.xDomain(points)
            self.change = Self.change(points, kind: kind)
        }

        /// Marks plot clamped values: the domain deliberately trims outliers, and
        /// a point drawn outside it would otherwise be sliced flat by the plot's
        /// clip. Riding the edge reads as "off the chart" instead of as a glitch.
        func clamped(_ value: Double) -> Double {
            min(max(value, yDomain.lowerBound), yDomain.upperBound)
        }

        func nearestPoint(to date: Date) -> PortfolioPoint? {
            points.min { abs($0.date.timeIntervalSince(date)) < abs($1.date.timeIntervalSince(date)) }
        }

        func accessibilitySummary(kind: Kind) -> String {
            guard let last = points.last else { return "No data" }
            let current = kind == .pnl ? Format.signedUSD(last.value) : Format.usd(last.value)
            guard let change else { return current }
            return "\(current), \(Format.signedUSD(change.absolute)) over the period"
        }

        private static func change(_ points: [PortfolioPoint], kind: Kind) -> Change? {
            guard points.count >= 2, let first = points.first, let last = points.last else { return nil }
            let absolute = last.value - first.value
            let percent: Double? = (kind == .accountValue && first.value > 0)
                ? (absolute / first.value) * 100
                : nil
            return Change(absolute: absolute, percent: percent)
        }

        /// Bars always grow from zero, so zero is always in range.
        static func barDomain(_ bars: [PnLBar]) -> ClosedRange<Double> {
            let lo = min(0, bars.map(\.delta).min() ?? 0)
            let hi = max(0, bars.map(\.delta).max() ?? 0)
            if lo == hi { return -1...1 }
            let pad = (hi - lo) * 0.12
            return (lo == 0 ? 0 : lo - pad)...(hi == 0 ? 0 : hi + pad)
        }

        /// Leaves a sliver of room at the trailing edge so the "now" marker sits
        /// inside the plot instead of being sliced in half by the clip.
        private static func xDomain(_ points: [PortfolioPoint]) -> ClosedRange<Date> {
            guard let first = points.first?.date, let last = points.last?.date, first < last else {
                let now = points.first?.date ?? Date()
                return now...now.addingTimeInterval(1)
            }
            let span = last.timeIntervalSince(first)
            return first...last.addingTimeInterval(span * 0.02)
        }

        /// Frames the visible range around the meaningful movement rather than
        /// anchoring to zero — a single funding spike shouldn't crush a week of
        /// activity into a flat line. Trims the extreme 2% at each end, but always
        /// keeps the latest reading in view.
        private static func yDomain(_ points: [PortfolioPoint], kind: Kind) -> ClosedRange<Double> {
            let values = points.map(\.value).sorted()
            guard let first = values.first, let last = values.last else { return 0...1 }

            func percentile(_ p: Double) -> Double {
                let idx = Int((Double(values.count - 1) * p).rounded())
                return values[idx]
            }

            var lo = values.count >= 10 ? percentile(0.02) : first
            var hi = values.count >= 10 ? percentile(0.98) : last
            if let current = points.last?.value {
                lo = min(lo, current)
                hi = max(hi, current)
            }
            if kind == .pnl {
                lo = min(lo, 0)
                hi = max(hi, 0)
            }
            if lo == hi { return (lo - 1)...(hi + 1) }
            let pad = (hi - lo) * 0.12
            return (lo - pad)...(hi + pad)
        }
    }
}

extension PortfolioPeriod {
    var accessibilityLabel: String {
        switch self {
        case .day: return "one day"
        case .week: return "one week"
        case .month: return "one month"
        case .allTime: return "all time"
        }
    }
}
