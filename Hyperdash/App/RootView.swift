import SwiftUI

struct RootView: View {
    @EnvironmentObject private var settings: AppSettings
    @EnvironmentObject private var lock: AppLock

    var body: some View {
        if settings.biometricLockEnabled && !lock.isUnlocked {
            LockScreen()
        } else {
            MainTabView()
        }
    }
}

struct MainTabView: View {
    var body: some View {
        TabView {
            WalletsListView()
                .tabItem { Label("Wallets", systemImage: "wallet.bifold") }
            SettingsView()
                .tabItem { Label("Settings", systemImage: "gearshape") }
        }
    }
}

struct LockScreen: View {
    @EnvironmentObject private var lock: AppLock

    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "lock.shield")
                .font(.system(size: 56))
                .foregroundStyle(.tint)
            Text("Hyperdash is locked")
                .font(.title2.weight(.semibold))
            Button {
                Task { await lock.unlock() }
            } label: {
                Label("Unlock", systemImage: "faceid")
                    .frame(maxWidth: 220)
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
        .task { await lock.unlock() }
    }
}
