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

            SummaryMetricsRow(metrics: [
                .init("Perps Equity", Format.usd(perps.accountValue)),
                .init("Spot Value", Format.usd(snapshot.spotUSDValue)),
                .init("Withdrawable", Format.usd(perps.withdrawableValue))
            ])

            if !perps.openPositions.isEmpty {
                Divider()
                SummaryMetricsRow(metrics: [
                    .init("Account Leverage", Format.leverage(snapshot.accountLeverage),
                          tint: leverageTint(snapshot.accountLeverage)),
                    .init("Margin Used", Format.usd(perps.totalMarginUsed)),
                    .init("Maint. Margin", Format.usd(perps.maintenanceMarginUsed))
                ])
            }
        }
        .padding(.vertical, 4)
    }

    private func leverageTint(_ leverage: Double) -> Color {
        switch leverage {
        case ..<3: return .primary
        case 3..<10: return .cautionText
        default: return .lossText
        }
    }
}
