import SwiftUI

extension Notification.Name {
    static let deviceDidShake = Notification.Name("app.deviceDidShake")
}

private final class ShakeDetectingViewController: UIViewController {
    override var canBecomeFirstResponder: Bool { true }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        becomeFirstResponder()
    }

    override func motionEnded(_ motion: UIEvent.EventSubtype, with event: UIEvent?) {
        if motion == .motionShake {
            NotificationCenter.default.post(name: .deviceDidShake, object: nil)
        }
        super.motionEnded(motion, with: event)
    }
}

private struct ShakeDetector: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> UIViewController { ShakeDetectingViewController() }
    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {}
}

extension View {
    func onShake(perform action: @escaping () -> Void) -> some View {
        background(ShakeDetector().allowsHitTesting(false))
            .onReceive(NotificationCenter.default.publisher(for: .deviceDidShake)) { _ in action() }
    }
}
