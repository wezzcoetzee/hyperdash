import SwiftUI
import Charts

extension ClosedRange {
    /// Marks plot clamped values: a point outside a framed domain would be
    /// sliced flat by the plot's clip. Riding the edge reads as "off the chart".
    func clamping(_ value: Bound) -> Bound {
        Swift.min(Swift.max(value, lowerBound), upperBound)
    }
}

struct ChartPlaceholder: View {
    var body: some View {
        RoundedRectangle(cornerRadius: Theme.surfaceRadius)
            .fill(Color.secondary.opacity(0.12))
            .accessibilityHidden(true)
    }
}

enum ChartMarks {
    /// An invisible point that carries a high/low caption.
    @ChartContentBuilder
    static func extremeLabel(at date: Date, y: Double, position: AnnotationPosition, text: String) -> some ChartContent {
        PointMark(x: .value("Time", date), y: .value("Value", y))
            .symbolSize(1)
            .foregroundStyle(.clear)
            .annotation(position: position, spacing: 2,
                        overflowResolution: .init(x: .fit(to: .chart), y: .fit(to: .chart))) {
                Text(text)
                    .font(.caption2)
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
    }
}
