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
    @Published var walletSort: WalletSort {
        didSet { defaults.set(walletSort.rawValue, forKey: Keys.walletSort) }
    }

    /// Redacts every `.privacySensitive()` figure; applied once at the root (`MainTabView`).
    @Published var privacyMode: Bool {
        didSet { defaults.set(privacyMode, forKey: Keys.privacyMode) }
    }

    private let defaults: UserDefaults

    /// Chart choices are read by view models and cards that have no settings
    /// instance, so they live in `UserDefaults.standard` behind static accessors.
    static var chartPeriod: PortfolioPeriod {
        get { PortfolioPeriod(rawValue: UserDefaults.standard.string(forKey: Keys.chartPeriod) ?? "") ?? .week }
        set { UserDefaults.standard.set(newValue.rawValue, forKey: Keys.chartPeriod) }
    }

    /// Key for `@AppStorage` of `PnLChartStyle`.
    static let pnlChartStyleKey = Keys.pnlChartStyle

    private enum Keys {
        static let chartPeriod = "settings.chartPeriod"
        static let pnlChartStyle = "settings.pnlChartStyle"
        static let network = "settings.network"
        static let biometricLock = "settings.biometricLock"
        static let iCloudSync = "settings.iCloudSync"
        static let appearance = "settings.appearance"
        static let walletSort = "settings.walletSort"
        static let privacyMode = "settings.privacyMode"
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
        self.privacyMode = defaults.bool(forKey: Keys.privacyMode)
        self.walletSort = defaults.string(forKey: Keys.walletSort).flatMap(WalletSort.init(rawValue:)) ?? .custom
    }
}
