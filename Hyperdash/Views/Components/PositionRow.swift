import SwiftUI

struct PositionRow: View {
    let position: Position
    let markPrice: Double?

    private var liqDistance: Double? {
        guard let mark = markPrice else { return nil }
        return position.liquidationDistancePct(markPrice: mark)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top) {
                Text(position.coin).font(.headline)
                DirectionTag(isLong: position.isLong)
                Text(Format.leverage(Double(position.leverage.value)))
                    .font(.caption.weight(.semibold))
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
                Spacer(minLength: 8)
                VStack(alignment: .trailing, spacing: 1) {
                    Text(Format.signedUSD(position.unrealizedPnlValue))
                        .font(.subheadline.weight(.semibold))
                        .monospacedDigit()
                        .foregroundStyle(.directionText(isPositive: position.unrealizedPnlValue >= 0))
                    Text(Format.percent(position.returnOnEquityValue * 100))
                        .font(.caption2)
                        .monospacedDigit()
                        .foregroundStyle(.directionText(isPositive: position.returnOnEquityValue >= 0))
                }
            }

            fieldGroup([
                ("Size", Format.number(position.absoluteSize, fractionDigits: 4)),
                ("Entry", position.entryPrice.map(Format.price) ?? "—"),
                ("Mark", markPrice.map(Format.price) ?? "—")
            ])

            fieldGroup([
                ("Notional", Format.usd(position.notionalValue)),
                ("Funding", Format.signedUSD(position.fundingSinceOpen))
            ])

            LiquidationBar(
                liquidationPrice: position.liquidationPrice,
                distancePct: liqDistance
            )
        }
        .padding(.vertical, 4)
    }

    private func fieldGroup(_ fields: [(String, String)]) -> some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .top, spacing: 16) {
                ForEach(fields, id: \.0) { field($0.0, $0.1) }
            }
            VStack(alignment: .leading, spacing: 4) {
                ForEach(fields, id: \.0) { pair in
                    HStack(spacing: 6) {
                        Text(pair.0).foregroundStyle(.secondary)
                        Text(pair.1).fontWeight(.medium).monospacedDigit()
                    }
                }
            }
        }
        .font(.caption)
    }

    private func field(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(label).foregroundStyle(.secondary)
            Text(value).fontWeight(.medium).monospacedDigit()
        }
    }
}

struct DirectionTag: View {
    let isLong: Bool
    var body: some View {
        Text(isLong ? "LONG" : "SHORT")
            .font(.caption2.weight(.bold))
            .padding(.horizontal, 6).padding(.vertical, 2)
            .background(Color.direction(isPositive: isLong).opacity(Theme.badgeFillOpacity))
            .foregroundStyle(Color.directionText(isPositive: isLong))
            .clipShape(RoundedRectangle(cornerRadius: 4))
    }
}

struct LiquidationBar: View {
    let liquidationPrice: Double?
    let distancePct: Double?

    private var tint: Color {
        guard let d = distancePct else { return .secondary }
        switch d {
        case ..<5: return .lossText
        case 5..<15: return .cautionText
        default: return .gainText
        }
    }

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "shield.lefthalf.filled")
                .foregroundStyle(tint)
                .accessibilityHidden(true)
            if let liq = liquidationPrice {
                Text("Liq. \(Format.price(liq))")
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            } else {
                Text("No liquidation price").foregroundStyle(.secondary)
            }
            Spacer()
            if let d = distancePct {
                Text("\(Format.number(d, fractionDigits: 1))% away")
                    .fontWeight(.semibold)
                    .monospacedDigit()
                    .foregroundStyle(tint)
            }
        }
        .font(.caption)
    }
}
