import SwiftUI

struct EditAgentKeyView: View {
    let wallet: Wallet
    let onChange: () -> Void

    @EnvironmentObject private var store: WalletStore
    @EnvironmentObject private var settings: AppSettings
    @Environment(\.dismiss) private var dismiss

    @State private var agentKey = ""
    @State private var errorMessage: String?
    @State private var confirmRemoval = false
    @FocusState private var agentKeyFocused: Bool

    private var hasExistingKey: Bool { store.hasAgentKey(wallet) }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    SecureField("Agent (API) wallet private key", text: $agentKey)
                        .font(.body.monospaced())
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .focused($agentKeyFocused)
                } header: {
                    Text(hasExistingKey ? "Replace Key" : "Add Key")
                } footer: {
                    Text("Generate an API wallet at app.hyperliquid.xyz/API and paste its private key. It can trade but cannot withdraw. Stored in the Keychain\(settings.iCloudSyncEnabled ? " and synced via iCloud" : " on this device only").")
                }

                if hasExistingKey {
                    Section {
                        Button("Remove agent key", role: .destructive) {
                            confirmRemoval = true
                        }
                    } footer: {
                        Text("Removing the key makes this wallet read-only.")
                    }
                }

                if let errorMessage {
                    Section {
                        Text(errorMessage).foregroundStyle(.lossText)
                    }
                }
            }
            .navigationTitle(hasExistingKey ? "Replace Agent Key" : "Add Agent Key")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save(agentKey) }
                        .disabled(agentKey.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .confirmationDialog("Remove agent key?", isPresented: $confirmRemoval, titleVisibility: .visible) {
                Button("Remove", role: .destructive) { save(nil) }
            } message: {
                Text("You can add a new key at any time.")
            }
            .onAppear {
                // Defer until after the sheet presentation finishes; immediate focus is often ignored.
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    agentKeyFocused = true
                }
            }
        }
    }

    private func save(_ keyHex: String?) {
        do {
            try store.setAgentKey(keyHex, for: wallet, synchronizable: settings.iCloudSyncEnabled)
            onChange()
            dismiss()
        } catch {
            errorMessage = error.userMessage
        }
    }
}
