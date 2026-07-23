import Foundation

struct FeedbackSubmission {
    let category: FeedbackCategory
    let message: String
    let screenshot: Data?
    let screenName: String?
}

enum FeedbackError: LocalizedError {
    case notConfigured
    case missingToken
    case emptyMessage
    case requestFailed(status: Int, detail: String)

    var errorDescription: String? {
        switch self {
        case .notConfigured: return "Set the repository owner and name in GitHubFeedbackConfig."
        case .missingToken: return "Add a GitHub token in Settings first."
        case .emptyMessage: return "Describe what you'd like to change."
        case .requestFailed(let status, let detail): return "GitHub request failed (\(status)): \(detail)"
        }
    }
}

struct GitHubFeedbackService: Sendable {
    private let session: URLSession
    private let tokenProvider: @Sendable () -> String?

    init(session: URLSession = .shared,
         tokenProvider: @escaping @Sendable () -> String? = { GitHubTokenStore.load() }) {
        self.session = session
        self.tokenProvider = tokenProvider
    }

    func submit(_ submission: FeedbackSubmission) async throws -> URL {
        guard GitHubFeedbackConfig.isConfigured else { throw FeedbackError.notConfigured }
        guard let token = tokenProvider(), !token.isEmpty else { throw FeedbackError.missingToken }

        let trimmed = submission.message.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw FeedbackError.emptyMessage }

        var screenshotEmbed: String?
        if let screenshot = submission.screenshot {
            screenshotEmbed = try? await uploadScreenshot(screenshot, token: token)
        }

        let body = issueBody(message: trimmed, screenName: submission.screenName, screenshotEmbed: screenshotEmbed)
        return try await createIssue(
            title: issueTitle(category: submission.category, message: trimmed),
            body: body,
            label: submission.category.label,
            token: token
        )
    }

    private func issueTitle(category: FeedbackCategory, message: String) -> String {
        let firstLine = message.split(separator: "\n").first.map(String.init) ?? message
        let summary = firstLine.count > 72 ? String(firstLine.prefix(72)) + "…" : firstLine
        return "[\(category.title)] \(summary)"
    }

    private func issueBody(message: String, screenName: String?, screenshotEmbed: String?) -> String {
        var parts = [message]
        if let screenName { parts.append("**Screen:** \(screenName)") }
        if let screenshotEmbed { parts.append(screenshotEmbed) }
        parts.append("_Filed from the app on \(deviceDescription())._")
        return parts.joined(separator: "\n\n")
    }

    private func deviceDescription() -> String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "?"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "?"
        return "v\(version) (\(build))"
    }

    private func uploadScreenshot(_ data: Data, token: String) async throws -> String {
        let path = "\(GitHubFeedbackConfig.screenshotDirectory)/\(UUID().uuidString).png"
        let url = URL(string: "https://api.github.com/repos/\(GitHubFeedbackConfig.owner)/\(GitHubFeedbackConfig.repo)/contents/\(path)")!

        var request = authorizedRequest(url: url, method: "PUT", token: token)
        let payload: [String: Any] = [
            "message": "Add feedback screenshot",
            "content": data.base64EncodedString(),
            "branch": GitHubFeedbackConfig.branch
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: payload)
        try await send(request)

        let embedURL = "https://github.com/\(GitHubFeedbackConfig.owner)/\(GitHubFeedbackConfig.repo)/blob/\(GitHubFeedbackConfig.branch)/\(path)?raw=true"
        return "![screenshot](\(embedURL))"
    }

    private func createIssue(title: String, body: String, label: String, token: String) async throws -> URL {
        let url = URL(string: "https://api.github.com/repos/\(GitHubFeedbackConfig.owner)/\(GitHubFeedbackConfig.repo)/issues")!
        var request = authorizedRequest(url: url, method: "POST", token: token)
        let payload: [String: Any] = ["title": title, "body": body, "labels": [label]]
        request.httpBody = try JSONSerialization.data(withJSONObject: payload)

        let responseData = try await send(request)
        if let json = try? JSONSerialization.jsonObject(with: responseData) as? [String: Any],
           let htmlURL = json["html_url"] as? String,
           let issueURL = URL(string: htmlURL) {
            return issueURL
        }
        return url
    }

    private func authorizedRequest(url: URL, method: String, token: String) -> URLRequest {
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue("2022-11-28", forHTTPHeaderField: "X-GitHub-Api-Version")
        return request
    }

    @discardableResult
    private func send(_ request: URLRequest) async throws -> Data {
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw FeedbackError.requestFailed(status: -1, detail: "No HTTP response")
        }
        guard (200..<300).contains(http.statusCode) else {
            let detail = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw FeedbackError.requestFailed(status: http.statusCode, detail: detail)
        }
        return data
    }
}
