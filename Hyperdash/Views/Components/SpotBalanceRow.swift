import SwiftUI

struct SpotBalanceRow: View {
    let balance: SpotBalance
    let usdValue: Double?

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(balance.coin).font(.headline)
                Text("\(Format.number(balance.totalValue, fractionDigits: 4))\(balance.holdValue > 0 ? " · \(Format.number(balance.holdValue, fractionDigits: 4)) on hold" : "")")
                    .font(.caption)
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if let usdValue {
                Text(Format.usd(usdValue))
                    .font(.subheadline.weight(.semibold))
                    .monospacedDigit()
            }
        }
        .padding(.vertical, 2)
    }
}

struct OpenOrderRow: View {
    let order: OpenOrder

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(order.coin).font(.headline)
                    Text(order.sideLabel.uppercased())
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(Color.directionText(isPositive: order.isBuy))
                    Text(order.typeLabel)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                Text("\(Format.number(order.size, fractionDigits: 4)) @ \(Format.price(order.limitPrice))")
                    .font(.caption)
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(.vertical, 2)
    }
}
