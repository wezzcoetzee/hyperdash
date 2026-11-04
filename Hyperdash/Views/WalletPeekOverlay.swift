import SwiftUI

/// What the eye button reveals while held: the combined total and 24h move,
/// then every wallet ranked by value with a bar showing its size against the
/// largest one. Wallets still loading render as redacted placeholders.
///
/// Its figures are deliberately not `.privacySensitive()`: the overlay is the
/// way to reveal values while privacy mode is on.
struct WalletPeekOverlay: View {
    let wallets: [Wallet]
    let data: [UUID: WalletData]

    private var ranked: [Wallet] { WalletSort.value.sorted(wallets, data: data) }
    private var loaded: [WalletData] { wallets.compactMap { data[$0.id] } }
    private var largest: Double { loaded.map(\.value).max() ?? 0 }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                header
                    .padding(.bottom, 12)
                ForEach(ranked) { wallet in
                    row(wallet, data[wallet.id])
                    Divider()
                }
            }
            .padding(.horizontal)
            .padding(.top, 8)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Color(.systemBackground))
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("All Wallets")
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(Format.usd(loaded.reduce(0) { $0 + $1.value }))
                .font(.system(.largeTitle, design: .rounded).weight(.bold))
                .monospacedDigit()
                .minimumScaleFactor(0.6)
                .lineLimit(1)
            DayChangeText(change: DayChange.combined(loaded.compactMap(\.dayChange)), showsAmount: true)
                .font(.subheadline.monospaced().weight(.semibold))
        }
        .redacted(reason: loaded.isEmpty ? .placeholder : [])
    }

    private func row(_ wallet: Wallet, _ data: WalletData?) -> some View {
        VStack(spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                Text(wallet.name).font(.subheadline.weight(.semibold)).lineLimit(1)
                DayChangeText(change: data?.dayChange)
                    .font(.caption.monospaced())
                Spacer(minLength: 8)
                Text(data.map { Format.usd($0.value) } ?? "$00,000.00")
                    .font(.subheadline.monospaced().weight(.semibold))
            }
            ShareBar(fraction: data.map { largest > 0 ? max($0.value, 0) / largest : 0 } ?? 0)
        }
        .padding(.vertical, 10)
        .redacted(reason: data == nil ? .placeholder : [])
        .accessibilityElement(children: .combine)
    }
}

/// A thin track filled to `fraction`: neutral, because size is not a signal.
private struct ShareBar: View {
    let fraction: Double

    var body: some View {
        Capsule()
            .fill(Color(.tertiarySystemFill))
            .frame(height: 4)
            .overlay(alignment: .leading) {
                GeometryReader { proxy in
                    Capsule()
                        .fill(.primary)
                        .frame(width: proxy.size.width * min(max(fraction, 0), 1))
                }
            }
            .accessibilityHidden(true)
    }
}
