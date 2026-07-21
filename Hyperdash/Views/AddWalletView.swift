import SwiftUI

struct AddWalletView: View {
    @EnvironmentObject private var store: WalletStore
    @EnvironmentObject private var settings: AppSettings
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var address = ""
    @State private var icon: WalletIcon = .wallet
    @State private var agentKey = ""
    @State private var showAgentKey = false
    @State private var errorMessage: String?
    @FocusState private var nameFocused: Bool

    private var addressValid: Bool { Wallet.isValidAddress(address) }
    private var canSave: Bool { !name.trimmingCharacters(in: .whitespaces).isEmpty && addressValid }

    var body: some View {
        NavigationStack {
            Form {
                Section("Wallet") {
                    TextField("Name", text: $name)
                        .textInputAutocapitalization(.words)
                        .focused($nameFocused)
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

                Section("Icon") {
                    WalletIconPicker(selection: $icon)
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
            .onAppear {
                // Defer until after the sheet presentation finishes; immediate focus is often ignored.
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    nameFocused = true
                }
            }
        }
    }

    private func save() {
        do {
            try store.add(
                name: name.trimmingCharacters(in: .whitespaces),
                address: address,
                icon: icon,
                agentKeyHex: showAgentKey ? agentKey : nil,
                synchronizable: settings.iCloudSyncEnabled
            )
            dismiss()
        } catch {
            errorMessage = error.userMessage
        }
    }
}

struct WalletIconPicker: View {
    @Binding var selection: WalletIcon

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 12), count: 4)

    var body: some View {
        LazyVGrid(columns: columns, spacing: 14) {
            ForEach(WalletIcon.allCases) { icon in
                Button {
                    selection = icon
                } label: {
                    VStack(spacing: 6) {
                        Image(systemName: icon.rawValue)
                            .font(.title2)
                            .frame(width: 44, height: 36)
                            .background(selection == icon ? Color.accentColor.opacity(0.16) : Color.clear)
                            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                        Text(icon.label)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.plain)
                .foregroundStyle(selection == icon ? Color.accentColor : Color.primary)
                .accessibilityLabel(icon.label)
                .accessibilityAddTraits(selection == icon ? .isSelected : [])
            }
        }
        .padding(.vertical, 4)
    }
}
