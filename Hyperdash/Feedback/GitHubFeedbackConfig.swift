import Foundation

enum GitHubFeedbackConfig {
    static let owner = "wezzcoetzee"
    static let repo = "hyperdash"
    static let branch = "main"

    static let screenshotDirectory = "Feedback/screenshots"

    static var isConfigured: Bool {
        !owner.hasPrefix("REPLACE_") && !repo.hasPrefix("REPLACE_")
    }

    static let tokenHelpURL = URL(string: "https://github.com/settings/personal-access-tokens/new")!

    static let tokenNotice = "A fine-grained token scoped to this one repo with Issues: read/write (and Contents: read/write if you want screenshots attached). Stored only on this device."
}
