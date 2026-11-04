import Charts
import SwiftUI
import WidgetKit

/// The figures an entry renders, already formatted. Redacted entries keep the
/// shape of real figures so privacy mode never shifts the layout.
private struct Figures {
    let value: String
    let amount: String?
    let percent: String?
    /// Nil when there is no direction to signal (redacted, or no 24h history).
    let isPositive: Bool?
    let history: [PortfolioPoint]

    init?(_ content: PortfolioEntry.Content) {
        switch content {
        case .summary(let summary):
            let change = summary.dayChange
            value = Format.usd(summary.value, fractionDigits: 0)
            amount = change.map { Format.signedUSD($0.amount, fractionDigits: 0) }
            percent = change?.percent.map { Format.signedPercent($0, fractionDigits: 1) }
            isPositive = change?.isPositive
            history = summary.dayHistory
        case .redacted:
            value = "$••••••"
            amount = "••••"
            percent = "••••"
            isPositive = nil
            history = []
        case .noWallets, .unavailable:
            return nil
        }
    }

    var color: Color {
        isPositive.map { .directionText(isPositive: $0) } ?? .secondary
    }
}

private extension PortfolioEntry.Content {
    var message: String {
        switch self {
        case .noWallets: return "Add a wallet in Hyperdash"
        case .unavailable: return "Can't reach Hyperliquid"
        case .summary, .redacted: return ""
        }
    }
}

struct PortfolioWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: PortfolioEntry

    private var figures: Figures? { Figures(entry.content) }
    private var isTestnet: Bool { entry.network == .testnet }

    var body: some View {
        Group {
            switch family {
            case .accessoryInline: inline
            case .accessoryRectangular: rectangular
            default: small
            }
        }
        .containerBackground(.background, for: .widget)
    }

    private var small: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 4) {
                Text("ALL WALLETS").foregroundStyle(.secondary)
                if isTestnet { Text("TESTNET").foregroundStyle(.cautionText) }
            }
            .font(.caption2.weight(.semibold))
            Spacer(minLength: 0)
            if let figures {
                Text(figures.value)
                    .font(.system(.title3, design: .monospaced, weight: .bold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                if let amount = figures.amount {
                    Text("\(amount) 24h")
                        .font(.caption.monospaced())
                        .foregroundStyle(figures.color)
                }
                Sparkline(points: figures.history, color: figures.color)
                    .frame(height: 30)
                    .padding(.top, 6)
            } else {
                Text(entry.content.message)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                Spacer(minLength: 0)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }

    private var rectangular: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(isTestnet ? "Hyperdash Testnet" : "Hyperdash")
                .font(.caption2)
                .foregroundStyle(.secondary)
            if let figures {
                Text(figures.value)
                    .font(.system(.headline, design: .monospaced, weight: .bold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                if let percent = figures.percent {
                    Text("\(percent) 24h").font(.caption.monospaced())
                }
            } else {
                Text(entry.content.message).font(.caption)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var inline: Text {
        guard let figures else { return Text(entry.content.message) }
        return Text([figures.value, figures.percent].compactMap { $0 }.joined(separator: " "))
    }
}

/// The combined day of account value, scaled to its own range so the shape
/// of the day reads rather than its distance from zero.
private struct Sparkline: View {
    let points: [PortfolioPoint]
    let color: Color

    var body: some View {
        if let low = points.map(\.value).min(), let high = points.map(\.value).max(), points.count >= 2 {
            Chart(points, id: \.date) { point in
                LineMark(x: .value("Time", point.date), y: .value("Value", point.value))
                    .interpolationMethod(.monotone)
                    .lineStyle(StrokeStyle(lineWidth: 1.5, lineCap: .round))
                    .foregroundStyle(color)
            }
            .chartXAxis(.hidden)
            .chartYAxis(.hidden)
            .chartLegend(.hidden)
            .chartYScale(domain: low...(high > low ? high : low + 1))
        } else {
            Color.clear
        }
    }
}

#Preview(as: .systemSmall) {
    PortfolioWidget()
} timeline: {
    PortfolioEntry.sample
    PortfolioEntry(date: .now, network: .testnet, content: .redacted)
}

#Preview(as: .accessoryRectangular) {
    PortfolioWidget()
} timeline: {
    PortfolioEntry.sample
}
