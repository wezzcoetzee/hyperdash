import SwiftUI

/// Grid of headline account stats, styled after the copy-trade vault dashboard.
struct VaultStatGrid: View {
    let snapshot: WalletSnapshot

    private var pnl: Double { snapshot.totalUnrealizedPnl }

    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]

    var body: some View {
        LazyVGrid(columns: columns, spacing: 12) {
            VaultStatCard(label: "Balance (USDC)", value: Format.usd(snapshot.accountBalanceUSDC))
            VaultStatCard(label: "Account Leverage", value: Format.leverage(snapshot.perps.accountLeverage))
            VaultStatCard(
                label: "Total P/L",
                value: Format.signedUSD(pnl),
                tint: pnl == 0 ? .primary : .directionText(isPositive: pnl >= 0)
            )
            VaultStatCard(label: "Open Positions", value: "\(snapshot.perps.openPositions.count)")
        }
    }
}

struct VaultStatCard: View {
    let label: String
    let value: String
    var subtitle: String? = nil
    var tint: Color = .primary

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label.uppercased())
                .font(.caption2.weight(.semibold))
                .tracking(0.5)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.system(.title2, design: .rounded).weight(.bold))
                .monospacedDigit()
                .foregroundStyle(tint)
                .minimumScaleFactor(0.6)
                .lineLimit(1)
            if let subtitle {
                Text(subtitle)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 72, alignment: .leading)
        .padding(12)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12))
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
        .background(Color(.tertiarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 10))
    }
}
