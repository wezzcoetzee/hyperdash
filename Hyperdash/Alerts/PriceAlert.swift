import Foundation

/// A user-defined price-crossing alert on a perp mark. One-shot: it arms once
/// price is seen on the opposite side of the target, fires when price crosses
/// to the target side, then stays triggered until deleted or reset.
struct PriceAlert: Identifiable, Codable, Equatable {
    enum Direction: String, Codable, CaseIterable, Identifiable {
        case above
        case below

        var id: String { rawValue }
        var label: String { self == .above ? "Rises to" : "Falls to" }
        var crossedLabel: String { self == .above ? "rose to" : "fell to" }
    }

    let id: UUID
    var coin: String
    var target: Double
    var direction: Direction
    var isEnabled: Bool
    /// True once price has been observed on the opposite side of the target,
    /// so an alert set at an already-satisfied price waits for a real crossing.
    var isArmed: Bool
    /// Set when the alert fires; nil means still pending.
    var triggeredAt: Date?

    init(
        id: UUID = UUID(),
        coin: String,
        target: Double,
        direction: Direction,
        isEnabled: Bool = true,
        isArmed: Bool = false,
        triggeredAt: Date? = nil
    ) {
        self.id = id
        self.coin = coin
        self.target = target
        self.direction = direction
        self.isEnabled = isEnabled
        self.isArmed = isArmed
        self.triggeredAt = triggeredAt
    }

    var isPending: Bool { isEnabled && triggeredAt == nil }
}

/// Persisted alert configuration (everything except the transient fired-liquidation set).
struct AlertConfig: Codable, Equatable {
    var liquidationEnabled: Bool
    var liquidationThresholdPct: Double
    var priceAlerts: [PriceAlert]

    static let `default` = AlertConfig(
        liquidationEnabled: false,
        liquidationThresholdPct: 10,
        priceAlerts: []
    )

    var hasAny: Bool { liquidationEnabled || priceAlerts.contains(where: \.isPending) }
}
