import Foundation
import BackgroundTasks
import UserNotifications

/// Delivery is best-effort: iOS decides when to run the task, so alerts can be
/// delayed. The seam a future push server would replace for real-time alerts.
enum AlertScheduler {
    static let taskIdentifier = "com.wcoetzee.hyperdash.alerts.refresh"

    /// Must be called before the app finishes launching (from `App.init`).
    /// `makeRunner` is invoked on each background wake to build a runner with
    /// the current wallets and session.
    static func register(makeRunner: @escaping () async -> AlertRunner?) {
        BGTaskScheduler.shared.register(forTaskWithIdentifier: taskIdentifier, using: nil) { task in
            let work = Task {
                if let runner = await makeRunner() {
                    await runner.run()
                }
                task.setTaskCompleted(success: true)
            }
            task.expirationHandler = { work.cancel() }
            schedule()
        }
    }

    static func schedule() {
        let request = BGAppRefreshTaskRequest(identifier: taskIdentifier)
        request.earliestBeginDate = Date(timeIntervalSinceNow: 15 * 60)
        try? BGTaskScheduler.shared.submit(request)
    }

    @discardableResult
    static func requestAuthorization() async -> Bool {
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        switch settings.authorizationStatus {
        case .authorized, .provisional, .ephemeral:
            return true
        case .denied:
            return false
        default:
            let granted = (try? await center.requestAuthorization(options: [.alert, .sound])) ?? false
            return granted
        }
    }
}
