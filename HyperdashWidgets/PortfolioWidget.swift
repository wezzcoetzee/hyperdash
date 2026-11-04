import SwiftUI
import WidgetKit

/// Total value and 24h change across every tracked wallet, on the home screen
/// (small, with a day sparkline) and the lock screen (rectangular, inline).
@main
struct PortfolioWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "PortfolioWidget", provider: PortfolioProvider()) { entry in
            PortfolioWidgetView(entry: entry)
        }
        .configurationDisplayName("Portfolio")
        .description("Total value and 24h change across your wallets.")
        .supportedFamilies([.systemSmall, .accessoryRectangular, .accessoryInline])
    }
}

struct PortfolioEntry: TimelineEntry {
    enum Content: Equatable {
        case summary(PortfolioSummary)
        /// Privacy mode is on: show the layout, never the figures.
        case redacted
        case noWallets
        case unavailable
    }

    let date: Date
    let network: HyperliquidNetwork
    let content: Content
}

struct PortfolioProvider: TimelineProvider {
    private static let refreshInterval: TimeInterval = 15 * 60
    /// A failed fetch retries sooner than a good one goes stale.
    private static let retryInterval: TimeInterval = 5 * 60

    func placeholder(in context: Context) -> PortfolioEntry { .sample }

    func getSnapshot(in context: Context, completion: @escaping (PortfolioEntry) -> Void) {
        guard !context.isPreview else { return completion(.sample) }
        Task { completion(await Self.load()) }
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<PortfolioEntry>) -> Void) {
        Task {
            let entry = await Self.load()
            let wait = entry.content == .unavailable ? Self.retryInterval : Self.refreshInterval
            completion(Timeline(entries: [entry], policy: .after(entry.date.addingTimeInterval(wait))))
        }
    }

    /// Fetches public `/info` data for the addresses the app shared. Any wallet
    /// failing fails the entry: a total missing a wallet would read as a loss.
    private static func load() async -> PortfolioEntry {
        let feed = WidgetFeed()
        func entry(_ content: PortfolioEntry.Content) -> PortfolioEntry {
            PortfolioEntry(date: .now, network: feed.network, content: content)
        }
        if SharedDefaults.privacyMode() { return entry(.redacted) }
        guard !feed.addresses.isEmpty else { return entry(.noWallets) }

        let client = HyperliquidClient(network: feed.network)
        let info = InfoService(client: client, meta: MetaService(client: client))
        do {
            let wallets = try await withThrowingTaskGroup(
                of: (value: Double, portfolio: PortfolioResponse).self
            ) { group in
                for address in feed.addresses {
                    group.addTask {
                        async let snapshot = info.snapshot(address: address)
                        // A missing portfolio only blanks the change and sparkline.
                        let portfolio = (try? await info.portfolio(address: address)) ?? PortfolioResponse(windows: [:])
                        return ((try await snapshot).accountBalanceUSDC, portfolio)
                    }
                }
                return try await group.reduce(into: []) { $0.append($1) }
            }
            return entry(.summary(PortfolioSummary(wallets)))
        } catch {
            return entry(.unavailable)
        }
    }
}

extension PortfolioEntry {
    /// Widget gallery and placeholder content.
    static var sample: PortfolioEntry {
        let start = Date.now.addingTimeInterval(-86_400)
        let values = [98_200, 98_900, 98_400, 99_600, 100_300, 99_800, 101_240.0]
        let history = values.enumerated().map {
            PortfolioPoint(date: start.addingTimeInterval(Double($0.offset) * 14_400), value: $0.element)
        }
        let pnl = [PortfolioPoint(date: start, value: 0), PortfolioPoint(date: .now, value: 1_893)]
        let portfolio = PortfolioResponse(windows: ["day": PortfolioWindow(accountValueHistory: history, pnlHistory: pnl)])
        return PortfolioEntry(date: .now, network: .mainnet,
                              content: .summary(PortfolioSummary([(value: 101_240, portfolio: portfolio)])))
    }
}
