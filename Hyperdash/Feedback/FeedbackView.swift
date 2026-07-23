import SwiftUI

struct FeedbackView: View {
    enum SubmitState: Equatable {
        case editing, submitting, succeeded
        case failed(String)
    }

    let screenshot: UIImage?
    let screenName: String?
    var service = GitHubFeedbackService()

    @Environment(\.dismiss) private var dismiss

    @State private var category: FeedbackCategory = .bug
    @State private var message = ""
    @State private var includeScreenshot = true
    @State private var state: SubmitState = .editing

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Type", selection: $category) {
                        ForEach(FeedbackCategory.allCases) { category in
                            Label(category.title, systemImage: category.systemImage).tag(category)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                Section("What would you like to change?") {
                    TextEditor(text: $message).frame(minHeight: 120)
                }

                if screenshot != nil {
                    Section {
                        Toggle("Attach screenshot", isOn: $includeScreenshot)
                        if includeScreenshot, let screenshot {
                            Image(uiImage: screenshot)
                                .resizable()
                                .scaledToFit()
                                .frame(maxHeight: 220)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                    }
                }

                statusSection
            }
            .navigationTitle("Send Feedback")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { submitButton }
            }
        }
    }

    @ViewBuilder
    private var statusSection: some View {
        switch state {
        case .editing, .submitting:
            EmptyView()
        case .succeeded:
            Section { Label("Feedback filed. Thanks!", systemImage: "checkmark.circle.fill").foregroundStyle(.green) }
        case .failed(let message):
            Section { Label(message, systemImage: "exclamationmark.triangle.fill").foregroundStyle(.red) }
        }
    }

    @ViewBuilder
    private var submitButton: some View {
        if state == .submitting {
            ProgressView()
        } else {
            Button("Submit") { submit() }
                .disabled(message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
    }

    private func submit() {
        state = .submitting
        let submission = FeedbackSubmission(
            category: category,
            message: message,
            screenshot: includeScreenshot ? screenshot?.pngData() : nil,
            screenName: screenName
        )
        Task {
            do {
                _ = try await service.submit(submission)
                state = .succeeded
                try? await Task.sleep(for: .seconds(1))
                dismiss()
            } catch {
                state = .failed(error.localizedDescription)
            }
        }
    }
}
