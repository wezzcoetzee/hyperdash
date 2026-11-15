import SwiftUI

/// A core-DEX coin's market at the top of a detail list, Stocks-style: the
/// current price as the one headline, the change over the chosen range, the
/// chart, and a stats section. Renders as two list sections.
struct CoinMarketSection: View {
    let coin: String

    @EnvironmentObject private var settings: AppSettings
    @StateObject private var chart = CoinChartModel()
    @State private var range: CandleRange = .day
    @State private var scrubbed: Candle?
    @State private var stats: Loadable<CoinStats> = .loading
    @AppStorage(AppSettings.coinChartStyleKey) private var style: ChartStyle = .standard

    private static let plotHeight: CGFloat = 220

    private var request: CoinChartModel.Request {
        .init(coin: coin, range: range, network: settings.network)
    }

    var body: some View {
        Section {
            VStack(alignment: .leading, spacing: 12) {
                header
                plot
                ChartRangePicker(selection: $range, options: CandleRange.allCases)
            }
            .task(id: request) { await loadChart() }
            .task(id: settings.network) { await loadStats() }
            .onChange(of: range) { _, _ in scrubbed = nil }
            .onChange(of: style) { _, _ in scrubbed = nil }
        }
        .listRowBackground(Color.clear)
        .listRowSeparator(.hidden)

        Section("Stats") { statRows }
    }

    // MARK: Header

    private var candles: [Candle] { chart.candles.value ?? [] }

    private var price: Double? {
        if let scrubbed { return scrubbed.close }
        if let mark = stats.value?.markPrice, mark > 0 { return mark }
        return candles.last?.close
    }

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 2) {
                if let price {
                    Text(Format.price(price))
                        .font(.system(.largeTitle, design: .rounded).weight(.bold))
                        .monospacedDigit()
                        .contentTransition(.numericText())
                } else {
                    Text("$00,000.00")
                        .font(.system(.largeTitle, design: .rounded).weight(.bold))
                        .monospacedDigit()
                        .redacted(reason: .placeholder)
                }
                subline
            }
            Spacer(minLength: 8)
            ChartStyleToggle()
        }
    }

    @ViewBuilder
    private var subline: some View {
        if let scrubbed {
            Text(scrubbed.openTime, format: CoinChart.scrubDateFormat(for: range))
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
        } else if let change = PriceChange(over: candles) {
            // Sign and arrow carry the meaning; colour only reinforces it.
            HStack(spacing: 4) {
                Image(systemName: change.absolute >= 0 ? "arrow.up.right" : "arrow.down.right")
                    .imageScale(.small)
                Text(Format.signedPrice(change.absolute)).monospacedDigit()
                if let percent = change.percent {
                    Text("(\(Format.signedPercent(percent, fractionDigits: 2)))").monospacedDigit()
                }
            }
            .font(.caption.weight(.semibold))
            .foregroundStyle(change.absolute == 0 ? Color.secondary : .directionText(isPositive: change.absolute > 0))
        } else {
            Text("+$0,000.00 (+0.00%)")
                .font(.caption.weight(.semibold))
                .monospacedDigit()
                .redacted(reason: .placeholder)
        }
    }

    // MARK: Plot

    @ViewBuilder
    private var plot: some View {
        switch chart.candles {
        case .loading:
            CoinChart.Placeholder().frame(height: Self.plotHeight)
        case .failed:
            ChartRetryRow { Task { await loadChart() } }
                .frame(maxWidth: .infinity, minHeight: Self.plotHeight)
        case .loaded(let candles) where candles.isEmpty:
            Text("No price history yet.")
                .font(.caption).foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, minHeight: Self.plotHeight)
        case .loaded(let candles):
            CoinChart(candles: candles, style: style, scrubbed: $scrubbed)
                .frame(height: Self.plotHeight)
        }
    }

    // MARK: Stats

    @ViewBuilder
    private var statRows: some View {
        switch stats {
        case .failed:
            ChartRetryRow(message: "Couldn't load market stats.") { Task { await loadStats() } }
        case .loading:
            statRow("Funding / 1h", "+0.0000%").redacted(reason: .placeholder)
            statRow("Open interest", "$0.0B").redacted(reason: .placeholder)
            statRow("24h volume", "$0.0B").redacted(reason: .placeholder)
        case .loaded(let stats):
            statRow("Funding / 1h", Format.signedPercent(stats.hourlyFunding * 100, fractionDigits: 4))
            statRow("Open interest", Format.abbreviatedUSD(stats.openInterestUSD))
            statRow("24h volume", Format.abbreviatedUSD(stats.dayVolumeUSD))
        }
    }

    private func statRow(_ title: String, _ value: String) -> some View {
        LabeledContent(title) { Text(value).monospacedDigit() }
    }

    // MARK: Loading

    private func loadChart() async {
        await chart.load(request, session: settings.session)
    }

    private func loadStats() async {
        stats = .loading
        do {
            let loaded = try await settings.session.info.coinStats(coin: coin)
            if Task.isCancelled { return }
            stats = loaded.map { .loaded($0) } ?? .failed("\(coin) has no market stats.")
        } catch {
            if !Task.isCancelled { stats = .failed(error.userMessage) }
        }
    }
}
