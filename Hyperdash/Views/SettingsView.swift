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

                GitHubFeedbackSettingsSection()

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

struct GitHubFeedbackSettingsSection: View {
    @State private var token = ""
    @State private var saved = false
    @State private var errorMessage: String?

    var body: some View {
        Section {
            SecureField("github_pat_...", text: $token)
                .textContentType(.password)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
            Button("Save Token") { save() }
                .disabled(token.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            if saved {
                Label("Saved", systemImage: "checkmark.circle.fill").foregroundStyle(.green)
            }
            if let errorMessage {
                Label(errorMessage, systemImage: "exclamationmark.triangle.fill").foregroundStyle(.red)
            }
            Link(destination: GitHubFeedbackConfig.tokenHelpURL) {
                Label("Create a token on GitHub", systemImage: "arrow.up.right.square")
            }
        } header: {
            Text("Feedback (GitHub)")
        } footer: {
            Text("Shake your device to file feedback as a GitHub issue. \(GitHubFeedbackConfig.tokenNotice)")
        }
        .onAppear { token = GitHubTokenStore.load() ?? "" }
    }

    private func save() {
        do {
            try GitHubTokenStore.save(token.trimmingCharacters(in: .whitespacesAndNewlines))
            saved = true
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
