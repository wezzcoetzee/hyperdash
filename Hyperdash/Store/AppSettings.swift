import Foundation
import Combine
import SwiftUI

enum AppAppearance: String, CaseIterable, Identifiable {
    case system
    case light
    case dark

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .system: return "System"
        case .light: return "Light"
        case .dark: return "Dark"
        }
    }

    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }
}

final class AppSettings: ObservableObject {
    @Published var network: HyperliquidNetwork {
        didSet {
            defaults.set(network.rawValue, forKey: Keys.network)
            session = HyperliquidSession(network: network)
        }
    }

    /// The resolved Hyperliquid environment. Follows `network`; views and
    /// view models take this instead of re-deriving clients from the raw
    /// network value.
    private(set) var session: HyperliquidSession
    @Published var biometricLockEnabled: Bool {
        didSet { defaults.set(biometricLockEnabled, forKey: Keys.biometricLock) }
    }
    @Published var iCloudSyncEnabled: Bool {
        didSet { defaults.set(iCloudSyncEnabled, forKey: Keys.iCloudSync) }
    }
    @Published var appearance: AppAppearance {
        didSet { defaults.set(appearance.rawValue, forKey: Keys.appearance) }
    }

    private let defaults: UserDefaults

    private enum Keys {
        static let network = "settings.network"
        static let biometricLock = "settings.biometricLock"
        static let iCloudSync = "settings.iCloudSync"
        static let appearance = "settings.appearance"
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        let raw = defaults.string(forKey: Keys.network) ?? HyperliquidNetwork.mainnet.rawValue
        let network = HyperliquidNetwork(rawValue: raw) ?? .mainnet
        self.network = network
        self.session = HyperliquidSession(network: network)
        self.biometricLockEnabled = defaults.bool(forKey: Keys.biometricLock)
        self.iCloudSyncEnabled = defaults.bool(forKey: Keys.iCloudSync)
        let appearanceRaw = defaults.string(forKey: Keys.appearance) ?? AppAppearance.system.rawValue
        self.appearance = AppAppearance(rawValue: appearanceRaw) ?? .system
    }
}
