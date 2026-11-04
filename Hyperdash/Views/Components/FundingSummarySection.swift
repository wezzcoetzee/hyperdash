import SwiftUI

/// Net funding over 24h and 7d plus a per-coin 7d breakdown. Loads its own data
/// so the wallet snapshot isn't held up by it; renders nothing without history.
struct FundingSummarySection: View {
    let address: String
    let session: HyperliquidSession

    private enum Phase {
        case loading
        case loaded(FundingSummary?)
        case failed
    }

    @State private var phase = Phase.loading

    var body: some View {
        Group {
            switch phase {
            case .loading, .loaded(nil):
                EmptyView()
            case .loaded(let summary?):
                Section("Funding") {
                    netRow("Net 24h", summary.net24h)
                    netRow("Net 7d", summary.net7d)
                    ForEach(summary.byCoin, id: \.coin) { total in
                        netRow(total.coin, total.net)
                            .font(.footnote)
                    }
                }
            case .failed:
                Section {
                    HStack {
                        Text("Couldn't load funding")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Button("Retry") { Task { await load() } }
                            .font(.footnote)
                    }
                }
            }
        }
        .task(id: "\(session.network)\(address)") { await load() }
    }

    private func netRow(_ title: String, _ value: Double) -> some View {
        LabeledContent(title) {
            Text(Format.signedUSD(value))
                .monospacedDigit()
                .foregroundStyle(Color.directionText(isPositive: value >= 0))
        }
    }

    private func load() async {
        do {
            let payments = try await session.info.funding(
                address: address, since: Date().addingTimeInterval(-7 * 24 * 3600))
            phase = .loaded(FundingSummary(payments: payments))
        } catch is CancellationError {
        } catch {
            phase = .failed
        }
    }
}
