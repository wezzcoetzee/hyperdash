import Foundation

extension String {
    /// Hyperliquid returns numeric fields as strings. This parses them locale-independently.
    var hlDouble: Double {
        Double(self) ?? 0
    }
}

enum Format {
    static func usd(_ value: Double, fractionDigits: Int = 2) -> String {
        let sign = value < 0 ? "-" : ""
        let n = abs(value)
        return "\(sign)$\(number(n, fractionDigits: fractionDigits))"
    }

    static func signedUSD(_ value: Double, fractionDigits: Int = 2) -> String {
        let sign = value >= 0 ? "+" : "-"
        return "\(sign)$\(number(abs(value), fractionDigits: fractionDigits))"
    }

    static func number(_ value: Double, fractionDigits: Int = 2) -> String {
        let formatter = decimalFormatter(fractionDigits: fractionDigits)
        return formatter.string(from: NSNumber(value: value)) ?? String(format: "%.\(fractionDigits)f", value)
    }

    private static let formatterCache = NSCache<NSNumber, NumberFormatter>()

    private static func decimalFormatter(fractionDigits: Int) -> NumberFormatter {
        let key = NSNumber(value: fractionDigits)
        if let cached = formatterCache.object(forKey: key) { return cached }
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.minimumFractionDigits = fractionDigits
        f.maximumFractionDigits = fractionDigits
        f.usesGroupingSeparator = true
        formatterCache.setObject(f, forKey: key)
        return f
    }

    static func percent(_ value: Double, fractionDigits: Int = 1) -> String {
        "\(number(value, fractionDigits: fractionDigits))%"
    }

    static func signedPercent(_ value: Double, fractionDigits: Int = 2) -> String {
        let sign = value >= 0 ? "+" : "-"
        return "\(sign)\(number(abs(value), fractionDigits: fractionDigits))%"
    }

    static func leverage(_ value: Double) -> String {
        "\(number(value, fractionDigits: value >= 10 ? 0 : 1))x"
    }

    /// Compact price formatting that keeps precision for low-priced assets.
    static func price(_ value: Double) -> String {
        let digits: Int
        switch abs(value) {
        case 0..<1: digits = 5
        case 1..<100: digits = 3
        default: digits = 2
        }
        return "$\(number(value, fractionDigits: digits))"
    }
}
