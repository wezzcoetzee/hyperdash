import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var settings: AppSettings
    @EnvironmentObject private var alerts: AlertStore
    @State private var notificationsDenied = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Network", selection: $settings.network) {
                        ForEach(HyperliquidNetwork.allCases) { network in
                            Text(network.displayName).tag(network)
                        }
                    }
                } header: {
                    Text("Network")
                } footer: {
                    Text("Testnet uses api.hyperliquid-testnet.xyz. Always verify trading on testnet first.")
                }

                Section {
                    Picker("Appearance", selection: $settings.appearance) {
                        ForEach(AppAppearance.allCases) { appearance in
                            Text(appearance.displayName).tag(appearance)
                        }
                    }
                } header: {
                    Text("Appearance")
                }

                Section {
                    Toggle("Require Face ID / passcode", isOn: $settings.biometricLockEnabled)
                } header: {
                    Text("Security")
                } footer: {
                    Text("Locks the app on launch. Trades always require authentication regardless of this setting.")
                }

                Section {
                    Toggle("Liquidation alerts", isOn: liquidationBinding)
                    if alerts.config.liquidationEnabled {
                        Stepper(
                            "Warn within \(Int(alerts.config.liquidationThresholdPct))%",
                            value: $alerts.config.liquidationThresholdPct,
                            in: 1...50, step: 1
                        )
                    }
                    NavigationLink {
                        PriceAlertsView()
                    } label: {
                        LabeledContent("Price alerts", value: pendingPriceAlertsLabel)
                    }
                } header: {
                    Text("Alerts")
                } footer: {
                    if notificationsDenied {
                        Text("Notifications are turned off. Enable them for Hyperdash in the iOS Settings app.")
                    } else {
                        Text("Delivered via background refresh, so timing depends on iOS and may be delayed. Not a substitute for a stop order.")
                    }
                }

                Section {
                    Toggle("Sync wallets via iCloud", isOn: $settings.iCloudSyncEnabled)
                } header: {
                    Text("iCloud")
                } footer: {
                    Text("Syncs wallet names, addresses, and agent keys across your devices using iCloud Keychain. Applies to keys saved after enabling.")
                }

                Section("About") {
                    LabeledContent("Version", value: appVersion)
                    Link("Hyperliquid API docs",
                         destination: URL(string: "https://hyperliquid.gitbook.io/hyperliquid-docs")!)
                    Link("Create an API wallet",
                         destination: URL(string: "https://app.hyperliquid.xyz/API")!)
                }
            }
            .navigationTitle("Settings")
        }
    }

    private var liquidationBinding: Binding<Bool> {
        Binding(
            get: { alerts.config.liquidationEnabled },
            set: { enabled in
                alerts.config.liquidationEnabled = enabled
                if enabled { requestAuthorization() }
            }
        )
    }

    private var pendingPriceAlertsLabel: String {
        let count = alerts.config.priceAlerts.filter(\.isPending).count
        return count == 0 ? "None" : "\(count)"
    }

    private func requestAuthorization() {
        Task {
            let granted = await AlertScheduler.requestAuthorization()
            notificationsDenied = !granted
        }
    }

    private var appVersion: String {
        let v = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?"
        let b = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "?"
        return "\(v) (\(b))"
    }
}
