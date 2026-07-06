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
                    result(icon: "xmark.octagon.fill", tint: .loss, title: "Failed", message: message)
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

    private func submit() async {
        await model.execute()
        if case .success = model.stage { onCompleted() }
    }

    private func finish() {
        if case .success = model.stage { onCompleted() }
        dismiss()
    }
}
