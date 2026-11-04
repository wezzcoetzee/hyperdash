import Foundation

/// The App Group container the app shares with its widget extension. Only
/// public data goes here; agent keys never leave the Keychain.
enum SharedDefaults {
    static let appGroup = "group.com.wcoetzee.hyperdash"

    /// Falls back to standard defaults when the group is unavailable (an
    /// unsigned build), where the widget simply sees no wallets.
    static let store = UserDefaults(suiteName: appGroup) ?? .standard

    enum Key {
        static let addresses = "widget.addresses"
        static let network = "widget.network"
        /// Set by the app's privacy mode. Widgets render redacted while true.
        static let privacyMode = "privacyMode"
    }

    static func privacyMode(in defaults: UserDefaults = store) -> Bool {
        defaults.bool(forKey: Key.privacyMode)
    }
}

/// What the widget needs to fetch on its own: which addresses to total, on
/// which network. Order is irrelevant to a total, so addresses are kept
/// deduplicated and sorted and reordering wallets never reloads the widget.
struct WidgetFeed: Equatable {
    let addresses: [String]
    let network: HyperliquidNetwork

    init(addresses: [String], network: HyperliquidNetwork) {
        self.addresses = Array(Set(addresses)).sorted()
        self.network = network
    }

    init(defaults: UserDefaults = SharedDefaults.store) {
        let raw = defaults.string(forKey: SharedDefaults.Key.network) ?? ""
        self.init(addresses: defaults.stringArray(forKey: SharedDefaults.Key.addresses) ?? [],
                  network: HyperliquidNetwork(rawValue: raw) ?? .mainnet)
    }

    /// Writes the feed, returning false when the defaults already held it so
    /// callers can skip reloading widget timelines.
    @discardableResult
    func publish(to defaults: UserDefaults = SharedDefaults.store) -> Bool {
        guard WidgetFeed(defaults: defaults) != self else { return false }
        defaults.set(addresses, forKey: SharedDefaults.Key.addresses)
        defaults.set(network.rawValue, forKey: SharedDefaults.Key.network)
        return true
    }
}
