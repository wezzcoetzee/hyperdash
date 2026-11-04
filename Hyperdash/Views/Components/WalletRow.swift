import SwiftUI

/// A wallet in the list: identity on the left, its value and 24h move on the
/// right, positions and leverage underneath. The liquidation flag only appears
/// once a position is inside the alert threshold.
struct WalletRow: View {
    let wallet: Wallet
    let hasKey: Bool
    var expiry: AgentKeyExpiry?
    let data: WalletData?
    let liquidationThresholdPct: Double

    private var nearLiquidation: Double? {
        data?.nearestLiquidationPct.flatMap { $0 <= liquidationThresholdPct ? $0 : nil }
    }

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: wallet.icon.rawValue)
                .foregroundStyle(.tint)
                .font(.title2)
                .frame(width: 28)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(wallet.name).font(.headline).lineLimit(1)
                    if let nearLiquidation {
                        Label("liq \(Format.percent(nearLiquidation, fractionDigits: 0))",
                              systemImage: "exclamationmark.triangle.fill")
                            .font(.caption2.weight(.semibold))
                            .monospacedDigit()
                            .foregroundStyle(.cautionText)
                            .accessibilityLabel("Liquidation risk, \(Format.percent(nearLiquidation)) away")
                    }
                    keyIndicator
                }
                detail
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer(minLength: 8)
            VStack(alignment: .trailing, spacing: 2) {
                Text(data.map { Format.usd($0.value) } ?? "$00,000.00")
                    .font(.subheadline.monospaced().weight(.semibold))
                DayChangeText(change: data?.dayChange)
                    .font(.caption.monospaced())
            }
            .redacted(reason: data == nil ? .placeholder : [])
        }
        .padding(.vertical, 4)
    }

    @ViewBuilder
    private var detail: some View {
        if let data, data.positionCount > 0 {
            let count = data.positionCount == 1 ? "1 position" : "\(data.positionCount) positions"
            Text(data.maxLeverage.map { "\(count) · \(Format.leverage(Double($0)))" } ?? count)
                .monospacedDigit()
        } else {
            Text(wallet.shortAddress).monospaced()
        }
    }

    @ViewBuilder
    private var keyIndicator: some View {
        if let expiry, expiry.status() != .healthy {
            AgentKeyBadge(expiry: expiry, compact: true)
        } else if hasKey {
            Image(systemName: "key.fill")
                .foregroundStyle(.secondary)
                .font(.caption)
                .accessibilityLabel("Trading enabled")
        }
    }
}

/// A signed 24h move: the percentage when there is a base to measure from,
/// otherwise the dollar amount. Sign always leads, so colour is never the only cue.
struct DayChangeText: View {
    let change: DayChange?
    /// Shows "+$120.00 (+1.2%)" instead of just the percentage.
    var showsAmount = false

    var body: some View {
        if let change {
            Text(text(change))
                .foregroundStyle(change.amount == 0 ? Color.secondary : Color.directionText(isPositive: change.isPositive))
        } else {
            Text("+0.00%").hidden().accessibilityHidden(true)
        }
    }

    private func text(_ change: DayChange) -> String {
        switch (showsAmount, change.percent) {
        case (true, let percent?): "\(Format.signedUSD(change.amount)) (\(Format.signedPercent(percent)))"
        case (false, let percent?): Format.signedPercent(percent)
        case (_, nil): Format.signedUSD(change.amount)
        }
    }
}

/// "Updated 12s ago", ticking at a coarse cadence so it never animates or
/// repaints faster than the figure can change.
struct UpdatedLabel: View {
    let date: Date?

    var body: some View {
        if let date {
            TimelineView(.periodic(from: .now, by: 10)) { context in
                Text(Self.text(since: date, now: context.date))
                    .font(.caption)
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
        }
    }

    static func text(since date: Date, now: Date) -> String {
        let seconds = max(Int(now.timeIntervalSince(date)), 0)
        switch seconds {
        case ..<10: return "Updated just now"
        case ..<60: return "Updated \(seconds)s ago"
        case ..<3600: return "Updated \(seconds / 60)m ago"
        default: return "Updated \(seconds / 3600)h ago"
        }
    }
}

/// The long-press preview of one wallet: value, 24h move and its largest positions.
struct WalletPreview: View {
    let wallet: Wallet
    let data: WalletData?

    private var topPositions: [DexPosition] {
        Array((data?.snapshot.openPositions ?? [])
            .sorted { $0.position.notionalValue > $1.position.notionalValue }
            .prefix(3))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Label(wallet.name, systemImage: wallet.icon.rawValue)
                    .font(.headline)
                Text(data.map { Format.usd($0.value) } ?? "$00,000.00")
                    .font(.title2.monospaced().weight(.semibold))
                DayChangeText(change: data?.dayChange, showsAmount: true)
                    .font(.caption.monospaced())
            }
            if !topPositions.isEmpty {
                Divider()
                ForEach(topPositions) { entry in
                    HStack {
                        Text(entry.position.coin).font(.subheadline.weight(.semibold))
                        DirectionTag(isLong: entry.position.isLong)
                        Spacer()
                        Text(Format.signedUSD(entry.position.unrealizedPnlValue))
                            .font(.subheadline.monospaced())
                            .foregroundStyle(.directionText(isPositive: entry.position.unrealizedPnlValue >= 0))
                    }
                }
            }
        }
        .redacted(reason: data == nil ? .placeholder : [])
        .padding()
        .frame(width: 300, alignment: .leading)
    }
}
