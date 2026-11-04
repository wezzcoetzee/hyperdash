import SwiftUI

/// Dashboard section: the groups closest to liquidation, with a push to all of them.
struct PositionGroupsSection: View {
    static let previewCount = 3

    let groups: [PositionGroup]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Positions".uppercased())
                    .font(.caption2.weight(.semibold)).tracking(0.5)
                    .foregroundStyle(.secondary)
                Spacer()
                if groups.count > Self.previewCount {
                    NavigationLink("See all \(groups.count)") { AllPositionGroupsView() }
                        .font(.caption.weight(.semibold))
                }
            }
            ForEach(Array(groups.prefix(Self.previewCount).enumerated()), id: \.element.id) { index, group in
                if index > 0 { Divider() }
                NavigationLink(value: group.key) { PositionGroupRow(group: group) }
                    .buttonStyle(.plain)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemGroupedBackground),
                    in: RoundedRectangle(cornerRadius: Theme.surfaceRadius))
    }
}

struct PositionGroupRow: View {
    @EnvironmentObject private var alerts: AlertStore
    let group: PositionGroup

    private var nearLiquidation: Bool {
        group.nearestLiquidationPct.map { $0 < alerts.config.liquidationThresholdPct } ?? false
    }

    private var summary: String {
        let wallets = group.walletCount == 1 ? "wallet" : "wallets"
        return "\(Format.number(group.totalSize, fractionDigits: 4)) · \(group.walletCount) \(wallets)"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 6) {
                Text(group.key.coin).font(.headline)
                if !group.key.dex.isEmpty { DexTag(dex: group.key.dex) }
                DirectionTag(isLong: group.key.isLong)
                Spacer(minLength: 8)
                Text(Format.signedUSD(group.unrealizedPnl))
                    .font(.subheadline.weight(.semibold)).monospacedDigit()
                    .foregroundStyle(.directionText(isPositive: group.unrealizedPnl >= 0))
            }
            HStack {
                Text(summary)
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
                Spacer(minLength: 8)
                if let liq = group.nearestLiquidationPct {
                    Text("liq \(Format.number(liq, fractionDigits: 1))%")
                        .monospacedDigit()
                        .foregroundStyle(nearLiquidation ? Color.cautionText : .secondary)
                }
            }
            .font(.caption)
        }
        .contentShape(Rectangle())
    }
}

/// Full list of groups.
struct AllPositionGroupsView: View {
    @EnvironmentObject private var store: WalletStore
    @EnvironmentObject private var walletData: WalletDataStore

    var body: some View {
        let groups = PositionGroup.groups(wallets: store.wallets, data: walletData.data)
        List {
            ForEach(groups) { group in
                NavigationLink(value: group.key) { PositionGroupRow(group: group) }
            }
        }
        .overlay {
            if groups.isEmpty {
                ContentUnavailableView("No open positions", systemImage: "chart.bar")
            }
        }
        .navigationTitle("Positions")
        .navigationBarTitleDisplayMode(.inline)
    }
}

/// The wallets holding one group, each pushing to its wallet.
struct PositionGroupDetailView: View {
    @EnvironmentObject private var store: WalletStore
    @EnvironmentObject private var walletData: WalletDataStore
    @EnvironmentObject private var alerts: AlertStore
    let key: PositionGroupKey

    private var group: PositionGroup? {
        PositionGroup.groups(wallets: store.wallets, data: walletData.data).first { $0.key == key }
    }

    var body: some View {
        List {
            if let group {
                Section { PositionGroupRow(group: group) }
                Section("Wallets") {
                    ForEach(group.holdings) { holding in
                        NavigationLink(value: holding.wallet) { holdingRow(holding) }
                    }
                }
            }
        }
        .overlay {
            if group == nil {
                ContentUnavailableView("Position closed", systemImage: "checkmark.circle")
            }
        }
        .navigationTitle(key.coin)
        .navigationBarTitleDisplayMode(.inline)
    }

    private func holdingRow(_ holding: PositionGroup.Holding) -> some View {
        let pnl = holding.position.unrealizedPnlValue
        let near = holding.liquidationPct.map { $0 < alerts.config.liquidationThresholdPct } ?? false
        return VStack(alignment: .leading, spacing: 2) {
            HStack {
                Text(holding.wallet.name).font(.headline)
                Spacer(minLength: 8)
                Text(Format.signedUSD(pnl))
                    .font(.subheadline.weight(.semibold)).monospacedDigit()
                    .foregroundStyle(.directionText(isPositive: pnl >= 0))
            }
            HStack {
                Text(Format.number(holding.position.absoluteSize, fractionDigits: 4))
                    .monospacedDigit().foregroundStyle(.secondary)
                Spacer(minLength: 8)
                if let liq = holding.liquidationPct {
                    Text("liq \(Format.number(liq, fractionDigits: 1))%")
                        .monospacedDigit()
                        .foregroundStyle(near ? Color.cautionText : .secondary)
                }
            }
            .font(.caption)
        }
    }
}
