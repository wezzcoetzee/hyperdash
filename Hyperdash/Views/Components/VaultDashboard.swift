import SwiftUI

/// The dashboard's headline: one dominant total balance in the Stocks-style
/// SF Rounded figure, with the rest of the portfolio totals as a quiet
/// supporting row beneath it.
struct DashboardSummaryCard: View {
    @EnvironmentObject private var settings: AppSettings
    let totals: DashboardViewModel.Totals

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Total Balance")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(Format.usd(totals.balance))
                    .font(.system(.largeTitle, design: .rounded).weight(.bold))
                    .monospacedDigit()
                    .minimumScaleFactor(0.6)
                    .lineLimit(1)
                    .privacySensitive()
            }
            .contentShape(Rectangle())
            .onTapGesture { settings.privacyMode.toggle() }
            .sensoryFeedback(.impact(weight: .light), trigger: settings.privacyMode)
            .accessibilityElement(children: .combine)
            .accessibilityAddTraits(.isButton)
            .accessibilityHint(settings.privacyMode ? "Shows balances" : "Hides balances")

            Divider()

            SummaryMetricsRow(metrics: [
                .init("Open PnL", Format.signedUSD(totals.openPnl),
                      tint: totals.openPnl == 0 ? .primary : .directionText(isPositive: totals.openPnl >= 0)),
                .init("Open Exposure", Format.usd(totals.openExposure)),
                .init("Wallets", "\(totals.walletCount)")
            ])
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemGroupedBackground),
                    in: RoundedRectangle(cornerRadius: Theme.surfaceRadius))
    }
}

/// A row of small supporting metrics beneath a hero figure. Shared by the
/// dashboard and wallet-detail summaries; collapses to a column when tight.
struct SummaryMetric: Identifiable {
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

struct SummaryMetricsRow: View {
    let metrics: [SummaryMetric]

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .top) {
                ForEach(metrics.indices, id: \.self) { index in
                    cell(metrics[index])
                    if index < metrics.count - 1 { Spacer(minLength: 8) }
                }
            }
            VStack(alignment: .leading, spacing: 12) {
                ForEach(metrics) { cell($0) }
            }
        }
    }

    private func cell(_ metric: SummaryMetric) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(metric.title).font(.caption2).foregroundStyle(.secondary)
            Text(metric.value)
                .font(.subheadline.weight(.semibold))
                .monospacedDigit()
                .foregroundStyle(metric.tint)
                .privacySensitive()
        }
    }
}

/// A single wallet's open PnL — the dashboard's best and worst performers,
/// ranked by PnL as a share of balance.
///
/// Deliberately a row rather than a card: the balance above is the screen's one
/// headline, and a pair of equal-weight cards with their own display figures
/// competes with it.
struct WalletPnLRow: View {
    let title: String
    let entry: DashboardViewModel.WalletPnL
    /// Ranks the row by dollars rather than percentage, leading with the amount.
    var leadsWithDollars = false

    private var tint: Color { .directionText(isPositive: entry.pnlPercent >= 0) }

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Image(systemName: entry.icon.rawValue)
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: 16)
            VStack(alignment: .leading, spacing: 2) {
                Text(entry.name)
                    .font(.subheadline)
                    .lineLimit(1)
                Text(title)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 8)
            VStack(alignment: .trailing, spacing: 2) {
                Text(leadsWithDollars ? Format.signedUSD(entry.pnl)
                                      : Format.signedPercent(entry.pnlPercent))
                    .font(.subheadline.weight(.semibold))
                    .monospacedDigit()
                    .foregroundStyle(tint)
                Text(leadsWithDollars ? Format.signedPercent(entry.pnlPercent)
                                      : Format.signedUSD(entry.pnl))
                    .font(.caption2)
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
            .lineLimit(1)
            .privacySensitive()
            Image(systemName: "chevron.right")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.tertiary)
                .accessibilityHidden(true)
        }
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }
}

/// Spot exposure pooled across every tracked wallet, one line per coin, so a
/// token split over two wallets reads as a single position.
struct SpotHoldingsCard: View {
    let holdings: [DashboardViewModel.SpotHolding]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Spot Holdings".uppercased())
                .font(.caption2.weight(.semibold)).tracking(0.5)
                .foregroundStyle(.secondary)
            ForEach(Array(holdings.enumerated()), id: \.element.id) { index, holding in
                if index > 0 { Divider() }
                row(holding)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemGroupedBackground),
                    in: RoundedRectangle(cornerRadius: Theme.surfaceRadius))
    }

    private func row(_ holding: DashboardViewModel.SpotHolding) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text(holding.coin).font(.subheadline.weight(.semibold)).lineLimit(1)
                Text(subtitle(holding))
                    .font(.caption2)
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 8)
            Text(holding.usdValue.map { Format.usd($0) } ?? "—")
                .font(.subheadline.weight(.semibold))
                .monospacedDigit()
                .lineLimit(1)
                .privacySensitive()
        }
        .accessibilityElement(children: .combine)
    }

    private func subtitle(_ holding: DashboardViewModel.SpotHolding) -> String {
        let amount = Format.number(holding.amount, fractionDigits: 4)
        guard holding.walletCount > 1 else { return amount }
        return "\(amount) · \(holding.walletCount) wallets"
    }
}

/// Short / long exposure split with a proportional bar, mirroring the dashboard.
struct ShortLongRatioCard: View {
    let exposure: SideExposure

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Short / long ratio").font(.headline)
                    Text("Open position exposure by side")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Text(exposure.ratio.map { Format.leverage($0) } ?? "—")
                    .font(.system(.title3, design: .rounded).weight(.bold))
                    .monospacedDigit()
            }

            if exposure.total > 0 {
                bar
                HStack(spacing: 12) {
                    exposureStat("Long exposure", side: exposure.long, share: exposure.longShare, isLong: true)
                    exposureStat("Short exposure", side: exposure.short, share: exposure.shortShare, isLong: false)
                }
            } else {
                Text("No open long or short exposure.")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }

    private var bar: some View {
        GeometryReader { geo in
            HStack(spacing: 0) {
                Color.green.frame(width: geo.size.width * (exposure.longShare ?? 0))
                Color.red.frame(width: geo.size.width * (exposure.shortShare ?? 0))
            }
        }
        .frame(height: 8)
        .clipShape(Capsule())
    }

    private func exposureStat(_ label: String, side: SideExposure.Side, share: Double?, isLong: Bool) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(label).font(.caption).foregroundStyle(.secondary)
                Spacer()
                Text(Format.usd(side.notional))
                    .font(.caption.weight(.semibold))
                    .monospacedDigit()
                    .foregroundStyle(.directionText(isPositive: isLong))
                    .privacySensitive()
            }
            HStack {
                Text("\(side.count) open").font(.caption2).foregroundStyle(.secondary)
                Spacer()
                if let share { Text(Format.percent(share * 100)).font(.caption2).monospacedDigit().foregroundStyle(.secondary) }
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity)
        .background(Color(.tertiarySystemGroupedBackground),
                    in: RoundedRectangle(cornerRadius: Theme.surfaceRadius))
    }
}
