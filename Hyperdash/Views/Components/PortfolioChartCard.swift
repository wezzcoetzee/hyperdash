import SwiftUI
import Charts

struct PortfolioChartCard: View {
    let title: String
    @Binding var period: PortfolioPeriod
    let points: [PortfolioPoint]
    var kind: Kind = .accountValue

    enum Kind { case accountValue, pnl }

    /// The point the user is currently scrubbing to, if any.
    @State private var selected: PortfolioPoint?

    private var lineColor: Color {
        switch kind {
        case .accountValue: return .brandMint
        case .pnl:
            let last = points.last?.value ?? 0
            return last == 0 ? .secondary : .directionText(isPositive: last >= 0)
        }
    }

    var body: some View {
        let frame = Frame(points: points, kind: kind)

        VStack(alignment: .leading, spacing: 12) {
            header(frame)

            Picker("Period", selection: $period) {
                ForEach(PortfolioPeriod.allCases) { p in Text(p.label).tag(p) }
            }
            .pickerStyle(.segmented)

            if frame.points.count < 2 {
                Text("Not enough history yet.")
                    .font(.caption).foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, minHeight: Self.plotHeight)
            } else {
                chart(frame)
            }
        }
        .padding(12)
        .background(Color(.secondarySystemGroupedBackground),
                    in: RoundedRectangle(cornerRadius: Theme.surfaceRadius))
        .onChange(of: period) { _, _ in selected = nil }
    }

    // MARK: - Header

    /// Title and the headline figure, with the window's change sitting under the
    /// title the way Stocks does — a period picker with no delta makes the user
    /// do the subtraction themselves.
    private func header(_ frame: Frame) -> some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title.uppercased())
                    .font(.caption2.weight(.semibold)).tracking(0.5)
                    .foregroundStyle(.secondary)
                if let selected {
                    Text(selected.date, format: scrubDateFormat)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .transition(.opacity)
                } else if let change = frame.change {
                    changeLabel(change)
                }
            }
            Spacer()
            if let value = selected?.value ?? frame.points.last?.value {
                Text(kind == .pnl ? Format.signedUSD(value) : Format.usd(value))
                    .font(.system(.subheadline, design: .rounded).weight(.bold))
                    .monospacedDigit()
                    .foregroundStyle(kind == .pnl ? lineColor : .primary)
                    .contentTransition(.numericText())
            }
        }
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
        .transition(.opacity)
    }

    // MARK: - Chart

    private static let plotHeight: CGFloat = 172

    private func chart(_ frame: Frame) -> some View {
        Chart {
            ForEach(frame.points, id: \.date) { p in
                AreaMark(
                    x: .value("Time", p.date),
                    yStart: .value("Floor", frame.areaFloor),
                    yEnd: .value("Value", p.value)
                )
                .interpolationMethod(.linear)
                .foregroundStyle(
                    LinearGradient(
                        colors: [lineColor.opacity(0.22), lineColor.opacity(0.0)],
                        startPoint: .top, endPoint: .bottom
                    )
                )

                LineMark(x: .value("Time", p.date), y: .value("Value", p.value))
                    .interpolationMethod(.linear)
                    .lineStyle(StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
                    .foregroundStyle(lineColor)
            }

            // Zero baseline matters most on PnL — mark where profit turns to loss.
            if kind == .pnl, frame.yDomain.contains(0) {
                RuleMark(y: .value("Zero", 0))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [3, 3]))
                    .foregroundStyle(Color.secondary.opacity(0.35))
            }

            if let selected {
                RuleMark(x: .value("Time", selected.date))
                    .lineStyle(StrokeStyle(lineWidth: 1))
                    .foregroundStyle(Color.secondary.opacity(0.35))
                marker(at: selected, diameter: 9)
            } else if let last = frame.points.last {
                marker(at: last, diameter: 7)
            }
        }
        .chartYScale(domain: frame.yDomain)
        .chartXScale(domain: frame.xDomain)
        .chartPlotStyle { $0.clipped() }
        .chartYAxis {
            AxisMarks(position: .trailing, values: .automatic(desiredCount: 3)) { value in
                AxisGridLine().foregroundStyle(Color.secondary.opacity(0.12))
                AxisValueLabel {
                    if let v = value.as(Double.self) {
                        Text(Format.abbreviatedUSD(v))
                            .font(.caption2)
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
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
                                selected = frame.nearestPoint(to: date)
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

    /// A dot ringed in the card's own background so it stays readable where the
    /// line doubles back under it.
    @ChartContentBuilder
    private func marker(at point: PortfolioPoint, diameter: CGFloat) -> some ChartContent {
        PointMark(x: .value("Time", point.date), y: .value("Value", point.value))
            .symbolSize((diameter + 4) * (diameter + 4))
            .foregroundStyle(Color(.secondarySystemGroupedBackground))
        PointMark(x: .value("Time", point.date), y: .value("Value", point.value))
            .symbolSize(diameter * diameter)
            .foregroundStyle(lineColor)
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

    private var scrubDateFormat: Date.FormatStyle {
        switch period {
        case .day: return .dateTime.hour().minute()
        case .week: return .dateTime.weekday(.abbreviated).hour().minute()
        case .month: return .dateTime.month(.abbreviated).day()
        case .allTime: return .dateTime.month(.abbreviated).day().year()
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
        let areaFloor: Double
        let change: Change?

        init(points raw: [PortfolioPoint], kind: Kind) {
            let points = PortfolioAggregator.trimmingFlatLeadIn(raw)
            let yDomain = Self.yDomain(points, kind: kind)
            self.points = points
            self.yDomain = yDomain
            self.xDomain = Self.xDomain(points)
            // PnL fills away from the zero line so a losing stretch reads as
            // hanging below it; account value fills from the floor.
            self.areaFloor = kind == .pnl ? 0 : yDomain.lowerBound
            self.change = Self.change(points, kind: kind)
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
