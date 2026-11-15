import SwiftUI

protocol ChartRangeOption: Identifiable, Hashable {
    var label: String { get }
    var accessibilityLabel: String { get }
}

extension CandleRange: ChartRangeOption {}
extension PortfolioPeriod: ChartRangeOption {}

/// Range buttons as plain text under a plot; the chosen one is filled.
struct ChartRangePicker<Option: ChartRangeOption>: View {
    @Binding var selection: Option
    let options: [Option]

    var body: some View {
        HStack(spacing: 4) {
            ForEach(options) { option in
                Button { selection = option } label: {
                    Text(option.label)
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(option == selection ? Color.primary : Color.secondary)
                        .frame(maxWidth: .infinity, minHeight: 32)
                        .background(option == selection ? Color.secondary.opacity(0.18) : Color.clear,
                                    in: RoundedRectangle(cornerRadius: 8))
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(option.accessibilityLabel)
                .accessibilityAddTraits(option == selection ? .isSelected : [])
            }
        }
        .sensoryFeedback(.selection, trigger: selection)
    }
}

/// A row of mutually exclusive options in a chart header. The caller draws
/// each option (an icon, a word) and sizes it; the toggle tints the chosen one.
struct ChartOptionToggle<Option: Hashable, Label: View>: View {
    @Binding var selection: Option
    let options: [Option]
    let accessibilityLabel: (Option) -> String
    @ViewBuilder let label: (Option) -> Label

    var body: some View {
        HStack(spacing: 0) {
            ForEach(options, id: \.self) { option in
                Button { selection = option } label: {
                    label(option)
                        .foregroundStyle(option == selection ? Color.primary : Color.secondary)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(accessibilityLabel(option))
                .accessibilityAddTraits(option == selection ? .isSelected : [])
            }
        }
        .sensoryFeedback(.selection, trigger: selection)
    }
}

/// Candles or Line. The choice is stored once and shared by every coin chart.
struct ChartStyleToggle: View {
    @AppStorage(AppSettings.coinChartStyleKey) private var style: ChartStyle = .standard

    var body: some View {
        ChartOptionToggle(selection: $style, options: ChartStyle.allCases, accessibilityLabel: { $0.label }) { option in
            Text(option.label)
                .font(.caption.weight(.semibold))
                .padding(.horizontal, 8)
                .frame(minHeight: 28)
        }
    }
}

/// Something that failed to load: one quiet line and a way back.
struct ChartRetryRow: View {
    var message = "Couldn't load the chart."
    let retry: () -> Void

    var body: some View {
        HStack {
            Text(message)
                .foregroundStyle(.secondary)
            Spacer()
            Button("Retry", action: retry)
        }
        .font(.caption)
    }
}
