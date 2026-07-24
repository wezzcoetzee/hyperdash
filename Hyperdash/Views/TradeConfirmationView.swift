import SwiftUI

struct TradeConfirmationView: View {
    let wallet: Wallet
    let context: TradeContext
    let onCompleted: () -> Void

    @EnvironmentObject private var settings: AppSettings
    @Environment(\.dismiss) private var dismiss
    @StateObject private var model: TradeViewModel

    init(wallet: Wallet, context: TradeContext, session: HyperliquidSession, onCompleted: @escaping () -> Void) {
        self.wallet = wallet
        self.context = context
        self.onCompleted = onCompleted
        let desk = TradeDesk(session: session, vault: DeviceVault(), wallet: wallet)
        _model = StateObject(wrappedValue: TradeViewModel(wallet: wallet, context: context, desk: desk))
    }

    var body: some View {
        NavigationStack {
            Group {
                switch model.stage {
                case .preparing:
                    loading("Preparing…")
                case .submitting:
                    loading("Submitting…")
                case .success(let message):
                    result(icon: "checkmark.seal.fill", tint: .gain, title: "Success", message: message)
                case .failed(let message):
                    result(icon: "xmark.octagon.fill", tint: .loss, title: "Failed",
                           message: Self.humanizedFailure(message))
                case .ready:
                    confirmation
                }
            }
            .navigationTitle(context.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { finish() }
                }
            }
        }
        .task { await model.prepare() }
        .interactiveDismissDisabled(model.stage == .submitting)
    }

    private var confirmation: some View {
        Form {
            if let plan = model.plan {
                Section {
                    ForEach(plan.rows, id: \.0) { row in
                        LabeledContent(row.0) {
                            Text(row.1).monospacedDigit()
                        }
                    }
                }
                if let warning = plan.warning {
                    Section {
                        Label(warning, systemImage: "exclamationmark.triangle.fill")
                            .font(.footnote)
                            .foregroundStyle(.cautionText)
                    }
                }
                Section {
                    Button(role: .destructive) {
                        Task { await submit() }
                    } label: {
                        Text(context.actionVerb).frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                } footer: {
                    Label("Requires Face ID / passcode. Network: \(settings.network.displayName).",
                          systemImage: "faceid")
                        .font(.caption)
                }
            }
        }
    }

    private func loading(_ text: String) -> some View {
        VStack(spacing: 16) {
            ProgressView()
            Text(text).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func result(icon: String, tint: Color, title: String, message: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: icon).font(.system(size: 52)).foregroundStyle(tint)
            Text(title).font(.title2.weight(.bold))
            Text(message)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .padding(.horizontal)
            Button("Done") { finish() }
                .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }

    /// Turns the terser Hyperliquid failure strings into plain guidance for the
    /// high-stakes moment. Unknown errors pass through unchanged.
    static func humanizedFailure(_ raw: String) -> String {
        let lower = raw.lowercased()
        if lower.contains("insufficient") && lower.contains("margin") {
            return "Not enough margin for this order. Reduce the size or add funds, then try again."
        }
        if lower.contains("insufficient") {
            return "Not enough balance for this order. Reduce the size, then try again."
        }
        if lower.contains("reduce only") || lower.contains("reduce-only") {
            return "This would increase the position, but it was sent as reduce-only. Close or flip the position instead."
        }
        if lower.contains("post only") || lower.contains("post-only") {
            return "A post-only order would have filled immediately. Adjust the price so it rests on the book."
        }
        if lower.contains("zero size") || lower.contains("must be greater") {
            return "The order size rounds to zero. Increase the amount and try again."
        }
        if lower.contains("http 429") || lower.contains("rate limit") {
            return "Hyperliquid is rate-limiting requests. Wait a moment and try again."
        }
        return raw
    }

    private func submit() async {
        await model.execute()
        if case .success = model.stage { onCompleted() }
    }

    private func finish() {
        if case .success = model.stage { onCompleted() }
        dismiss()
    }
}
