import Foundation
import Combine

/// Owns alert configuration and persists it to UserDefaults. The UI mutates it
/// on the main actor; the background runner reads/writes the same keys through
/// the static `AlertPersistence` helpers, and `reload()` picks up any changes
/// the runner made while the app was suspended.
@MainActor
final class AlertStore: ObservableObject {
    @Published var config: AlertConfig {
        didSet { AlertPersistence.save(config, to: defaults) }
    }

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.config = AlertPersistence.load(from: defaults)
    }

    /// Re-read from storage (e.g. after the background task fired alerts).
    func reload() {
        let loaded = AlertPersistence.load(from: defaults)
        if loaded != config { config = loaded }
    }

    func addPriceAlert(_ alert: PriceAlert) {
        config.priceAlerts.append(alert)
    }

    func removePriceAlert(_ alert: PriceAlert) {
        config.priceAlerts.removeAll { $0.id == alert.id }
    }

    /// Clears the triggered/armed state so a fired one-shot alert becomes active again.
    func resetPriceAlert(_ alert: PriceAlert) {
        guard let idx = config.priceAlerts.firstIndex(where: { $0.id == alert.id }) else { return }
        config.priceAlerts[idx].triggeredAt = nil
        config.priceAlerts[idx].isArmed = false
        config.priceAlerts[idx].isEnabled = true
    }
}

/// UserDefaults-backed persistence shared by the store (UI) and the runner (background).
enum AlertPersistence {
    private static let configKey = "alerts.config.v1"
    private static let firedKey = "alerts.firedLiquidations.v1"

    static func load(from defaults: UserDefaults) -> AlertConfig {
        guard let data = defaults.data(forKey: configKey),
              let decoded = try? JSONDecoder().decode(AlertConfig.self, from: data) else {
            return .default
        }
        return decoded
    }

    static func save(_ config: AlertConfig, to defaults: UserDefaults) {
        guard let data = try? JSONEncoder().encode(config) else { return }
        defaults.set(data, forKey: configKey)
    }

    static func loadFired(from defaults: UserDefaults) -> Set<String> {
        Set(defaults.stringArray(forKey: firedKey) ?? [])
    }

    static func saveFired(_ fired: Set<String>, to defaults: UserDefaults) {
        defaults.set(Array(fired), forKey: firedKey)
    }
}
