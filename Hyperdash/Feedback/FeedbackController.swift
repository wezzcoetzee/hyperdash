import SwiftUI

@MainActor
@Observable
final class FeedbackController {
    var isPresented = false
    var screenshot: UIImage?
    var screenName: String?

    func begin(screenName: String?) {
        screenshot = ScreenshotCapturer.captureKeyWindow()
        self.screenName = screenName
        isPresented = true
    }
}
