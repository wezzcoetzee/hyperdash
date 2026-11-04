import SwiftUI

@main
struct HyperdashApp: App {
    @StateObject private var walletStore: WalletStore
    @StateObject private var settings: AppSettings
    @StateObject private var alerts: AlertStore
    @StateObject private var expiryStore = AgentKeyExpiryStore()
    @StateObject private var walletData = WalletDataStore()
    @StateObject private var lock = AppLock()
    @Environment(\.scenePhase) private var scenePhase

    init() {
        let settings = AppSettings()
        let walletStore = WalletStore(iCloudSyncEnabled: settings.iCloudSyncEnabled)
        _settings = StateObject(wrappedValue: settings)
        _walletStore = StateObject(wrappedValue: walletStore)
        _alerts = StateObject(wrappedValue: AlertStore())

        // Registration must happen before launch completes. Read wallets/session
        // on the main actor at each wake so the runner always uses current state.
        AlertScheduler.register {
            let wallets = await MainActor.run { walletStore.wallets }
            let session = await MainActor.run { settings.session }
            return AlertRunner(session: session, wallets: wallets)
        }
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(walletStore)
                .environmentObject(settings)
                .environmentObject(alerts)
                .environmentObject(expiryStore)
                .environmentObject(walletData)
                .environmentObject(lock)
                .preferredColorScheme(settings.appearance.colorScheme)
                .onChange(of: scenePhase) { _, phase in
                    lock.handleScenePhase(phase)
                    handleScenePhase(phase)
                }
                .onChange(of: settings.iCloudSyncEnabled) { _, enabled in
                    walletStore.setiCloudSyncEnabled(enabled)
                }
                .task(id: autoRefreshKey) { await autoRefresh() }
        }
    }

    /// Restarts the refresh loop when the app activates, the network switches,
    /// or wallets are added or removed. Sorted so reordering doesn't restart it.
    private var autoRefreshKey: String {
        "\(scenePhase)-\(settings.network.rawValue)-\(walletStore.wallets.map(\.id.uuidString).sorted().joined())"
    }

    /// Refreshes every wallet now and every 30s after, only while the scene is
    /// active. Leaving the foreground changes the key, which cancels the loop.
    private func autoRefresh() async {
        guard scenePhase == .active else { return }
        while !Task.isCancelled {
            await walletData.load(wallets: walletStore.wallets, session: settings.session)
            try? await Task.sleep(for: .seconds(30))
        }
    }

    private func handleScenePhase(_ phase: ScenePhase) {
        switch phase {
        case .active:
            // Pick up any alerts fired by the background task while suspended,
            // then check once now so alerts also fire while the app is open.
            alerts.reload()
            Task {
                await AlertRunner(session: settings.session, wallets: walletStore.wallets).run()
                alerts.reload()
            }
        case .background:
            AlertScheduler.schedule()
        default:
            break
        }
    }
}
