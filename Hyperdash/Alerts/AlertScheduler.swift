import Foundation
import BackgroundTasks
import UserNotifications

/// Registers and schedules the background refresh task that drives alerts, and
/// owns the notification-authorization flow. Delivery is best-effort: iOS
/// decides when to run the task, so alerts can be delayed. This is the seam a
/// future push server would replace for real-time liquidation alerts.
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

    /// Queues the next background refresh. Safe to call repeatedly.
    static func schedule() {
        let request = BGAppRefreshTaskRequest(identifier: taskIdentifier)
        request.earliestBeginDate = Date(timeIntervalSinceNow: 15 * 60)
        try? BGTaskScheduler.shared.submit(request)
    }

    static func cancel() {
        BGTaskScheduler.shared.cancel(taskRequestWithIdentifier: taskIdentifier)
    }

    /// Prompts for notification permission. Returns whether it is authorized.
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
