import SwiftUI

/// The wallet's headline: one dominant total value in the Stocks-style SF
/// Rounded figure, with the supporting balances as a quiet row beneath it.
///
/// A `nil` snapshot renders the loading placeholder from this same layout, so
/// the skeleton reserves the real geometry and can't drift away from the loaded
/// card the way a hand-copied one does.
struct AccountSummaryCard: View {
    var snapshot: WalletSnapshot?

    private var isPlaceholder: Bool { snapshot == nil }

    var body: some View {
        if isPlaceholder {
            layout
                .redacted(reason: .placeholder)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Loading account summary")
        } else {
            layout
        }
    }

    private var layout: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Total Value")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(snapshot.map { Format.usd($0.totalAccountValue) } ?? Self.figurePlaceholder)
                    .font(.system(.largeTitle, design: .rounded).weight(.bold))
                    .monospacedDigit()
                    .minimumScaleFactor(0.6)
                    .lineLimit(1)
                    .privacySensitive()
            }

            Divider()

            SummaryMetricsRow(metrics: [
                perpsMetric,
                .init("Spot Value", balance(\.spotUSDValue)),
                .init("Withdrawable", balance(\.perps.withdrawableValue))
            ])

            // The risk row is genuinely conditional on holding positions, so the
            // placeholder leaves it out rather than reserving space that may
            // never fill.
            if let snapshot, !snapshot.openPositions.isEmpty {
                Divider()
                SummaryMetricsRow(metrics: [
                    .init("Account Leverage", Format.leverage(snapshot.accountLeverage),
                          tint: leverageTint(snapshot.accountLeverage)),
                    .init("Margin Used", Format.usd(snapshot.totalMarginUsed)),
                    .init("Maint. Margin", Format.usd(snapshot.maintenanceMarginUsed))
                ])
            }
        }
        .padding(.vertical, 4)
    }

    /// A unified account's perps equity is a slice of the spot balance shown
    /// beside it, so printing it here reads as double counting against the total.
    /// Open PnL is the part of the perp state that isn't already in spot.
    ///
    /// The placeholder takes the standard label — which of the two a wallet
    /// shows isn't known until its abstraction mode arrives with the snapshot.
    private var perpsMetric: SummaryMetric {
        guard let snapshot else { return .init("Perps Equity", Self.metricPlaceholder) }
        guard snapshot.valuesFromSpotAlone else {
            return .init("Perps Equity", Format.usd(snapshot.perpsAccountValue))
        }
        let pnl = snapshot.totalUnrealizedPnl
        return .init("Unrealized PnL", Format.signedUSD(pnl),
                     tint: pnl == 0 ? .primary : .directionText(isPositive: pnl > 0))
    }

    /// Digit-width stand-ins, so the placeholder occupies the same space the
    /// real figures will.
    private static let figurePlaceholder = "$000,000.00"
    private static let metricPlaceholder = "$0,000.00"

    private func balance(_ path: KeyPath<WalletSnapshot, Double>) -> String {
        guard let snapshot else { return Self.metricPlaceholder }
        return Format.usd(snapshot[keyPath: path])
    }

    private func leverageTint(_ leverage: Double) -> Color {
        switch leverage {
        case ..<3: return .primary
        case 3..<10: return .cautionText
        default: return .lossText
        }
    }
}
