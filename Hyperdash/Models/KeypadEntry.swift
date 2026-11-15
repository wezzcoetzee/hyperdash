import Foundation

/// The text behind the order ticket's custom keypad. Keeps input a valid
/// decimal at every keystroke, so the figure on screen always parses.
struct KeypadEntry: Equatable {
    enum Key: Hashable {
        case digit(Int)
        case point
        case delete
    }

    private(set) var text: String
    let maxFractionDigits: Int

    init(_ text: String = "", maxFractionDigits: Int) {
        self.text = text
        self.maxFractionDigits = maxFractionDigits
    }

    var value: Double { Double(text) ?? 0 }

    mutating func press(_ key: Key) {
        switch key {
        case .delete:
            if !text.isEmpty { text.removeLast() }
        case .point:
            guard maxFractionDigits > 0, !text.contains(".") else { return }
            text = (text.isEmpty ? "0" : text) + "."
        case .digit(let d):
            if let dot = text.firstIndex(of: ".") {
                guard text[text.index(after: dot)...].count < maxFractionDigits else { return }
            } else if text == "0" {
                text = ""
            }
            guard text.count < 12 else { return }
            text += String(d)
        }
    }

    mutating func set(_ value: Double) {
        text = value > 0 ? Wire.size(value, szDecimals: maxFractionDigits) : ""
    }
}
