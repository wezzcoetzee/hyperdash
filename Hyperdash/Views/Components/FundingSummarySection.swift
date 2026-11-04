import SwiftUI

/// Net funding over 24h and 7d plus a per-coin breakdown. Renders nothing
/// while loading or without history.
struct FundingSummarySection: View {
    let state: WalletDetailViewModel.FundingState
    let retry: () -> Void

    var body: some View {
        switch state {
        case .loading, .loaded(nil):
            EmptyView()
        case .loaded(let summary?):
            Section("Funding") {
                netRow("Net 24h", summary.net24h)
                netRow("Net \(FundingSummary.windowDays)d", summary.net7d)
                ForEach(summary.byCoin.indices, id: \.self) { index in
                    netRow(summary.byCoin[index].coin, summary.byCoin[index].net)
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
                    Button("Retry", action: retry)
                        .font(.footnote)
                }
            }
        }
    }

    private func netRow(_ title: String, _ value: Double) -> some View {
        LabeledContent(title) {
            Text(Format.signedUSD(value))
                .monospaced()
                .foregroundStyle(Color.directionText(isPositive: value >= 0))
        }
    }
}
