import SwiftUI
import UIKit

extension ShapeStyle where Self == Color {
    static var gain: Color { .green }
    static var loss: Color { .red }
    static var caution: Color { .orange }

    static func direction(isPositive: Bool) -> Color {
        isPositive ? .green : .red
    }

    /// Hyperliquid mint (#32E7CD). Used explicitly in Swift Charts, which does
    /// not inherit the app's `.accentColor` tint and otherwise falls back to blue.
    static var brandMint: Color { Color(red: 0.196, green: 0.906, blue: 0.804) }

    static var gainText: Color { Theme.adaptive(light: Theme.gainLight, dark: .systemGreen) }
    static var lossText: Color { Theme.adaptive(light: Theme.lossLight, dark: .systemRed) }
    static var cautionText: Color { Theme.adaptive(light: Theme.cautionLight, dark: .systemOrange) }

    static func directionText(isPositive: Bool) -> Color {
        isPositive ? gainText : lossText
    }
}

enum Theme {
    static let badgeFillOpacity: Double = 0.18
    static let networkFillOpacity: Double = 0.22

    /// `rounded.surface` from DESIGN.md — the one corner radius for cards and surfaces.
    static let surfaceRadius: CGFloat = 10

    static let gainLight = UIColor(red: 0.07, green: 0.44, blue: 0.22, alpha: 1)
    static let lossLight = UIColor(red: 0.75, green: 0.0, blue: 0.10, alpha: 1)
    static let cautionLight = UIColor(red: 0.62, green: 0.37, blue: 0.0, alpha: 1)

    static func adaptive(light: UIColor, dark: UIColor) -> Color {
        Color(UIColor { $0.userInterfaceStyle == .dark ? dark : light })
    }
}
