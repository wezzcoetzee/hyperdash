import SwiftUI

/// The dashboard's headline: one dominant total balance in the Stocks-style
/// SF Rounded figure, with the rest of the portfolio totals as a quiet
/// supporting row beneath it.
struct DashboardSummaryCard: View {
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
            }

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
        }
    }
}

/// Highlights a single wallet's open PnL — used for the dashboard's best and
/// worst performers, ranked by PnL as a share of balance.
struct WalletPnLCard: View {
    let title: String
    let entry: DashboardViewModel.WalletPnL

    private var isPositive: Bool { entry.pnlPercent >= 0 }
    private var tint: Color { .directionText(isPositive: isPositive) }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title.uppercased())
                .font(.caption2.weight(.semibold))
                .tracking(0.5)
                .foregroundStyle(.secondary)
            Text(Format.signedPercent(entry.pnlPercent))
                .font(.system(.title2, design: .rounded).weight(.bold))
                .monospacedDigit()
                .foregroundStyle(tint)
                .minimumScaleFactor(0.6)
                .lineLimit(1)
            HStack(spacing: 6) {
                Image(systemName: entry.icon.rawValue)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(entry.name)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                Spacer(minLength: 0)
                Text(Format.signedUSD(entry.pnl))
                    .font(.caption.weight(.semibold))
                    .monospacedDigit()
                    .foregroundStyle(tint)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 72, alignment: .leading)
        .padding(12)
        .background(Color(.secondarySystemGroupedBackground),
                    in: RoundedRectangle(cornerRadius: Theme.surfaceRadius))
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
