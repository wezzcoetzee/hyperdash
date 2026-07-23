import SwiftUI

struct RootView: View {
    @EnvironmentObject private var settings: AppSettings
    @EnvironmentObject private var lock: AppLock
    @State private var feedbackController = FeedbackController()

    private var isLocked: Bool {
        settings.biometricLockEnabled && !lock.isUnlocked
    }

    var body: some View {
        Group {
            if isLocked {
                LockScreen()
            } else {
                MainTabView()
            }
        }
        .onShake {
            guard !isLocked, !feedbackController.isPresented else { return }
            feedbackController.begin(screenName: nil)
        }
        .sheet(isPresented: $feedbackController.isPresented) {
            FeedbackView(
                screenshot: feedbackController.screenshot,
                screenName: feedbackController.screenName
            )
        }
    }
}

struct MainTabView: View {
    var body: some View {
        TabView {
            DashboardView()
                .tabItem { Label("Dashboard", systemImage: "chart.bar") }
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
