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
        case .accountValue: return Theme.brandMint
        case .pnl:
            let last = points.last?.value ?? 0
            return last == 0 ? .secondary : .directionText(isPositive: last >= 0)
        }
    }

    /// The value shown in the header — the scrubbed point when scrubbing,
    /// otherwise the latest reading.
    private var headlineValue: Double? {
        selected?.value ?? points.last?.value
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title.uppercased())
                        .font(.caption2.weight(.semibold)).tracking(0.5)
                        .foregroundStyle(.secondary)
                    if let selected {
                        Text(selected.date, format: .dateTime.month().day().hour().minute())
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .transition(.opacity)
                    }
                }
                Spacer()
                if let value = headlineValue {
                    Text(kind == .pnl ? Format.signedUSD(value) : Format.usd(value))
                        .font(.system(.subheadline, design: .rounded).weight(.bold))
                        .monospacedDigit()
                        .foregroundStyle(kind == .pnl ? lineColor : .primary)
                        .contentTransition(.numericText())
                }
            }

            Picker("Period", selection: $period) {
                ForEach(PortfolioPeriod.allCases) { p in Text(p.label).tag(p) }
            }
            .pickerStyle(.segmented)

            if points.count < 2 {
                Text("Not enough history yet.")
                    .font(.caption).foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, minHeight: 160)
            } else {
                chart
            }
        }
        .padding(12)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12))
    }

    private var chart: some View {
        Chart {
            ForEach(points, id: \.date) { p in
                AreaMark(
                    x: .value("Time", p.date),
                    yStart: .value("Floor", yDomain.lowerBound),
                    yEnd: .value("Value", p.value)
                )
                .interpolationMethod(.monotone)
                .foregroundStyle(
                    LinearGradient(
                        colors: [lineColor.opacity(0.20), lineColor.opacity(0.0)],
                        startPoint: .top, endPoint: .bottom
                    )
                )

                LineMark(x: .value("Time", p.date), y: .value("Value", p.value))
                    .interpolationMethod(.monotone)
                    .lineStyle(StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
                    .foregroundStyle(lineColor)
            }

            // Zero baseline matters most on PnL — mark where profit turns to loss.
            if kind == .pnl, yDomain.contains(0) {
                RuleMark(y: .value("Zero", 0))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [3, 3]))
                    .foregroundStyle(Color.secondary.opacity(0.25))
            }

            if let selected {
                RuleMark(x: .value("Time", selected.date))
                    .lineStyle(StrokeStyle(lineWidth: 1))
                    .foregroundStyle(Color.secondary.opacity(0.35))
                PointMark(x: .value("Time", selected.date), y: .value("Value", selected.value))
                    .symbolSize(80)
                    .foregroundStyle(lineColor)
            } else if let last = points.last {
                PointMark(x: .value("Time", last.date), y: .value("Value", last.value))
                    .symbolSize(60)
                    .foregroundStyle(lineColor)
            }
        }
        .chartYScale(domain: yDomain)
        .chartYAxis {
            AxisMarks(position: .trailing, values: .automatic(desiredCount: 3)) { value in
                AxisGridLine().foregroundStyle(Color.secondary.opacity(0.10))
                AxisValueLabel {
                    if let v = value.as(Double.self) {
                        Text(Format.usd(v, fractionDigits: 0))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .chartXAxis {
            AxisMarks(values: .automatic(desiredCount: 4)) { _ in
                AxisValueLabel()
                    .font(.caption2)
                    .foregroundStyle(.secondary)
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
                                selected = nearestPoint(to: date)
                            }
                            .onEnded { _ in selected = nil }
                    )
            }
        }
        .frame(height: 160)
        .animation(.easeOut(duration: 0.15), value: selected)
    }

    private func nearestPoint(to date: Date) -> PortfolioPoint? {
        points.min { abs($0.date.timeIntervalSince(date)) < abs($1.date.timeIntervalSince(date)) }
    }

    /// Frames the visible range around the meaningful movement rather than
    /// anchoring to zero — a single funding spike shouldn't crush a week of
    /// activity into a flat line. Trims the extreme 2% at each end, but always
    /// keeps the latest reading in view.
    private var yDomain: ClosedRange<Double> {
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
