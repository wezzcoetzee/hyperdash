import Foundation

/// Formats prices and sizes into Hyperliquid's wire strings.
///
/// Rules (from the API docs):
///   • Sizes are rounded to the asset's `szDecimals`.
///   • Prices allow ≤ 5 significant figures AND ≤ (MAX_DECIMALS − szDecimals)
///     decimal places, where MAX_DECIMALS is 6 for perps and 8 for spot.
///     Integer prices are always allowed.
///   • Values serialise with trailing zeros stripped and never in scientific
///     notation (mirrors the SDK's `float_to_wire`).
enum Wire {
    static func size(_ value: Double, szDecimals: Int) -> String {
        format(round(value, decimals: szDecimals), maxDecimals: szDecimals)
    }

    static func price(_ value: Double, szDecimals: Int, isSpot: Bool) -> String {
        let maxDecimals = (isSpot ? 8 : 6) - szDecimals
        let sigFigs = fiveSignificant(value)
        let rounded = round(sigFigs, decimals: max(0, maxDecimals))
        return format(rounded, maxDecimals: max(0, maxDecimals))
    }

    private static func fiveSignificant(_ value: Double) -> Double {
        guard value != 0 else { return 0 }
        let digits = 5
        let d = ceil(log10(abs(value)))
        let power = digits - Int(d)
        let magnitude = pow(10.0, Double(power))
        return (value * magnitude).rounded() / magnitude
    }

    private static func round(_ value: Double, decimals: Int) -> Double {
        guard decimals >= 0 else { return value }
        let m = pow(10.0, Double(decimals))
        return (value * m).rounded() / m
    }

    private static func format(_ value: Double, maxDecimals: Int) -> String {
        var s = String(format: "%.\(max(0, maxDecimals))f", value)
        if s.contains(".") {
            while s.hasSuffix("0") { s.removeLast() }
            if s.hasSuffix(".") { s.removeLast() }
        }
        return s == "-0" ? "0" : s
    }
}
