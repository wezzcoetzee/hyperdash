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
            LineMark(x: .value("Time", p.date), y: .value("Value", p.value))
                .interpolationMethod(.monotone)
                .foregroundStyle(lineColor)
            AreaMark(x: .value("Time", p.date), y: .value("Value", p.value))
                .interpolationMethod(.monotone)
                .foregroundStyle(lineColor.opacity(0.12))
        }
        .chartYAxis {
            AxisMarks { value in
                AxisGridLine()
                AxisValueLabel {
                    if let v = value.as(Double.self) { Text(Format.usd(v, fractionDigits: 0)) }
                }
            }
        }
        .chartXAxis { AxisMarks(values: .automatic(desiredCount: 4)) }
        .frame(height: 160)
    }
}
