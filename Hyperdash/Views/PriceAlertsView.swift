import SwiftUI

struct PriceAlertsView: View {
    @EnvironmentObject private var alerts: AlertStore
    @State private var adding = false

    var body: some View {
        List {
            if alerts.config.priceAlerts.isEmpty {
                ContentUnavailableView(
                    "No price alerts",
                    systemImage: "bell",
                    description: Text("Add an alert to be notified when a coin crosses a price.")
                )
            } else {
                ForEach(alerts.config.priceAlerts) { alert in
                    PriceAlertRow(alert: alert)
                        .swipeActions(edge: .trailing) {
                            Button(role: .destructive) {
                                alerts.removePriceAlert(alert)
                            } label: { Label("Delete", systemImage: "trash") }
                        }
                        .swipeActions(edge: .leading) {
                            if alert.triggeredAt != nil {
                                Button {
                                    alerts.resetPriceAlert(alert)
                                } label: { Label("Reset", systemImage: "arrow.clockwise") }
                                .tint(.blue)
                            }
                        }
                }
            }
        }
        .navigationTitle("Price Alerts")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { adding = true } label: { Image(systemName: "plus") }
            }
        }
        .sheet(isPresented: $adding) {
            AddPriceAlertView()
        }
    }
}

private struct PriceAlertRow: View {
    let alert: PriceAlert

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(alert.coin).font(.headline)
                Text("\(alert.direction.label) \(Format.price(alert.target))")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if alert.triggeredAt != nil {
                Label("Triggered", systemImage: "checkmark.circle")
                    .labelStyle(.iconOnly)
                    .foregroundStyle(.secondary)
            } else if !alert.isEnabled {
                Text("Off").font(.caption).foregroundStyle(.secondary)
            }
        }
    }
}

struct AddPriceAlertView: View {
    @EnvironmentObject private var alerts: AlertStore
    @Environment(\.dismiss) private var dismiss

    /// Optional prefilled coin (e.g. when opened from a position row).
    var coin: String = ""

    @State private var coinInput: String
    @State private var direction: PriceAlert.Direction = .above
    @State private var targetText = ""

    init(coin: String = "") {
        self.coin = coin
        _coinInput = State(initialValue: coin)
    }

    private var target: Double? {
        Double(targetText.trimmingCharacters(in: .whitespaces))
    }

    private var isValid: Bool {
        !coinInput.trimmingCharacters(in: .whitespaces).isEmpty && (target ?? 0) > 0
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Market") {
                    TextField("Coin (e.g. BTC)", text: $coinInput)
                        .textInputAutocapitalization(.characters)
                        .autocorrectionDisabled()
                        .disabled(!coin.isEmpty)
                }
                Section("Condition") {
                    Picker("Direction", selection: $direction) {
                        Text("Rises to").tag(PriceAlert.Direction.above)
                        Text("Falls to").tag(PriceAlert.Direction.below)
                    }
                    .pickerStyle(.segmented)
                    TextField("Target price", text: $targetText)
                        .keyboardType(.decimalPad)
                }
            }
            .navigationTitle("New Price Alert")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") { add() }.disabled(!isValid)
                }
            }
        }
    }

    private func add() {
        guard let target else { return }
        let alert = PriceAlert(
            coin: coinInput.trimmingCharacters(in: .whitespaces).uppercased(),
            target: target,
            direction: direction
        )
        alerts.addPriceAlert(alert)
        Task { await AlertScheduler.requestAuthorization() }
        dismiss()
    }
}
