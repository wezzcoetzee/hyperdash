import SwiftUI

@main
struct HyperdashApp: App {
    @StateObject private var walletStore: WalletStore
    @StateObject private var settings: AppSettings
    @StateObject private var lock = AppLock()
    @Environment(\.scenePhase) private var scenePhase

    init() {
        let settings = AppSettings()
        _settings = StateObject(wrappedValue: settings)
        _walletStore = StateObject(wrappedValue: WalletStore(iCloudSyncEnabled: settings.iCloudSyncEnabled))
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(walletStore)
                .environmentObject(settings)
                .environmentObject(lock)
                .preferredColorScheme(settings.appearance.colorScheme)
                .onChange(of: scenePhase) { _, phase in
                    lock.handleScenePhase(phase)
                }
                .onChange(of: settings.iCloudSyncEnabled) { _, enabled in
                    walletStore.setiCloudSyncEnabled(enabled)
                }
        }
    }
}
