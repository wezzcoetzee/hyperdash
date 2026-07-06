import SwiftUI
import Combine

/// Owns the lock policy: unlocks via biometrics and re-locks whenever the app
/// leaves the foreground.
@MainActor
final class AppLock: ObservableObject {
    @Published private(set) var isUnlocked = false

    private let authenticate: (String) async -> Bool

    init(authenticate: @escaping (String) async -> Bool = BiometricAuth.authenticate) {
        self.authenticate = authenticate
    }

    func unlock() async {
        isUnlocked = await authenticate("Unlock Hyperdash")
    }

    func handleScenePhase(_ phase: ScenePhase) {
        if phase == .background { isUnlocked = false }
    }
}
