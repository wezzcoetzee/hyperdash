import Foundation

enum FeedbackCategory: String, CaseIterable, Identifiable {
    case bug
    case feature
    case ui

    var id: String { rawValue }
    var label: String { rawValue }

    var title: String {
        switch self {
        case .bug: return "Bug"
        case .feature: return "Feature"
        case .ui: return "UI"
        }
    }

    var systemImage: String {
        switch self {
        case .bug: return "ladybug"
        case .feature: return "lightbulb"
        case .ui: return "paintbrush"
        }
    }
}
