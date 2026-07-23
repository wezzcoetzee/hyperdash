import SwiftUI
import Charts

struct PortfolioChartCard: View {
    let title: String
    @Binding var period: PortfolioPeriod
    let points: [PortfolioPoint]
    var kind: Kind = .accountValue

    enum Kind { case accountValue, pnl }

    private var lineColor: Color {
        switch kind {
        case .accountValue: return .accentColor
        case .pnl:
            let last = points.last?.value ?? 0
            return last == 0 ? .secondary : .directionText(isPositive: last >= 0)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(title.uppercased())
                    .font(.caption2.weight(.semibold)).tracking(0.5)
                    .foregroundStyle(.secondary)
                Spacer()
                if let latest = points.last?.value {
                    Text(kind == .pnl ? Format.signedUSD(latest) : Format.usd(latest))
                        .font(.system(.subheadline, design: .rounded).weight(.bold))
                        .monospacedDigit()
                        .foregroundStyle(kind == .pnl ? lineColor : .primary)
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
        Chart(points, id: \.date) { p in
            AreaMark(x: .value("Time", p.date), y: .value("Value", p.value))
                .interpolationMethod(.monotone)
                .foregroundStyle(
                    LinearGradient(
                        colors: [lineColor.opacity(0.22), lineColor.opacity(0.0)],
                        startPoint: .top, endPoint: .bottom
                    )
                )
            LineMark(x: .value("Time", p.date), y: .value("Value", p.value))
                .interpolationMethod(.monotone)
                .lineStyle(StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
                .foregroundStyle(lineColor)

            if let last = points.last, p.date == last.date {
                PointMark(x: .value("Time", last.date), y: .value("Value", last.value))
                    .symbolSize(60)
                    .foregroundStyle(lineColor)
            }
        }
        .chartYScale(domain: yDomain)
        .chartYAxis {
            AxisMarks(preferredPosition: .trailing, values: .automatic(desiredCount: 3)) { value in
                AxisGridLine().foregroundStyle(Color.secondary.opacity(0.12))
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
            AxisMarks(values: .automatic(desiredCount: 4)) { value in
                AxisValueLabel()
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(height: 160)
    }

    private var yDomain: ClosedRange<Double> {
        let values = points.map(\.value)
        guard let lo = values.min(), let hi = values.max() else { return 0...1 }
        if lo == hi { return (lo - 1)...(hi + 1) }
        let pad = (hi - lo) * 0.15
        return (lo - pad)...(hi + pad)
    }
}
