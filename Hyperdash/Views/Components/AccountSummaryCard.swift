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
                perpsMetric,
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

    /// A unified account's perps equity is a slice of the spot balance shown
    /// beside it, so printing it here reads as double counting against the total.
    /// Open PnL is the part of the perp state that isn't already in spot.
    private var perpsMetric: SummaryMetric {
        guard snapshot.valuesFromSpotAlone else {
            return .init("Perps Equity", Format.usd(perps.accountValue))
        }
        let pnl = snapshot.totalUnrealizedPnl
        return .init("Unrealized PnL", Format.signedUSD(pnl),
                     tint: pnl == 0 ? .primary : .directionText(isPositive: pnl > 0))
    }

    private func leverageTint(_ leverage: Double) -> Color {
        switch leverage {
        case ..<3: return .primary
        case 3..<10: return .cautionText
        default: return .lossText
        }
    }
}
