import SwiftUI

struct AccountSummaryCard: View {
    let snapshot: WalletSnapshot

    private var perps: PerpsState { snapshot.perps }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Total Value")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(Format.usd(snapshot.totalAccountValue))
                    .font(.system(.largeTitle, design: .rounded).weight(.bold))
                    .monospacedDigit()
                    .minimumScaleFactor(0.6)
                    .lineLimit(1)
            }

            Divider()

            metricsRow([
                Metric("Perps Equity", Format.usd(perps.accountValue)),
                Metric("Spot Value", Format.usd(snapshot.spotUSDValue)),
                Metric("Withdrawable", Format.usd(perps.withdrawableValue))
            ])

            if !perps.openPositions.isEmpty {
                Divider()
                metricsRow([
                    Metric("Account Leverage", Format.leverage(snapshot.accountLeverage),
                           tint: leverageTint(snapshot.accountLeverage)),
                    Metric("Margin Used", Format.usd(perps.totalMarginUsed)),
                    Metric("Maint. Margin", Format.usd(perps.maintenanceMarginUsed))
                ])
            }
        }
        .padding(.vertical, 4)
    }

    private struct Metric: Identifiable {
        var id: String { title }
        let title: String
        let value: String
        let tint: Color

        init(_ title: String, _ value: String, tint: Color = .primary) {
            self.title = title
            self.value = value
            self.tint = tint
        }
    }

    private func metricsRow(_ metrics: [Metric]) -> some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .top) {
                ForEach(metrics.indices, id: \.self) { index in
                    metricCell(metrics[index])
                    if index < metrics.count - 1 { Spacer(minLength: 8) }
                }
            }
            VStack(alignment: .leading, spacing: 12) {
                ForEach(metrics) { metricCell($0) }
            }
        }
    }

    private func metricCell(_ metric: Metric) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(metric.title).font(.caption2).foregroundStyle(.secondary)
            Text(metric.value)
                .font(.subheadline.weight(.semibold))
                .monospacedDigit()
                .foregroundStyle(metric.tint)
        }
    }

    private func leverageTint(_ leverage: Double) -> Color {
        switch leverage {
        case ..<3: return .primary
        case 3..<10: return .cautionText
        default: return .lossText
        }
    }
}
