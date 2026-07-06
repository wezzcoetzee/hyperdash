import SwiftUI

struct AddWalletView: View {
    @EnvironmentObject private var store: WalletStore
    @EnvironmentObject private var settings: AppSettings
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var address = ""
    @State private var agentKey = ""
    @State private var showAgentKey = false
    @State private var errorMessage: String?

    private var addressValid: Bool { Wallet.isValidAddress(address) }
    private var canSave: Bool { !name.trimmingCharacters(in: .whitespaces).isEmpty && addressValid }

    var body: some View {
        NavigationStack {
            Form {
                Section("Wallet") {
                    TextField("Name", text: $name)
                        .textInputAutocapitalization(.words)
                    TextField("Public address (0x…)", text: $address)
                        .font(.body.monospaced())
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    if !address.isEmpty && !addressValid {
                        Label("Not a valid 0x address", systemImage: "exclamationmark.triangle")
                            .font(.caption)
                            .foregroundStyle(.cautionText)
                    }
                }

                Section {
                    Toggle("Enable trading", isOn: $showAgentKey.animation())
                    if showAgentKey {
                        SecureField("Agent (API) wallet private key", text: $agentKey)
                            .font(.body.monospaced())
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                    }
                } header: {
                    Text("Trading (optional)")
                } footer: {
                    Text("Generate an API wallet at app.hyperliquid.xyz/API and paste its private key. It can trade but cannot withdraw. Stored in the Keychain\(settings.iCloudSyncEnabled ? " and synced via iCloud" : " on this device only").")
                }

                if let errorMessage {
                    Section {
                        Text(errorMessage).foregroundStyle(.lossText)
                    }
                }
            }
            .navigationTitle("Add Wallet")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }.disabled(!canSave)
                }
            }
        }
    }

    private func save() {
        do {
            try store.add(
                name: name.trimmingCharacters(in: .whitespaces),
                address: address,
                agentKeyHex: showAgentKey ? agentKey : nil,
                synchronizable: settings.iCloudSyncEnabled
            )
            dismiss()
        } catch {
            errorMessage = error.userMessage
        }
    }
}
