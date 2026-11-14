import SwiftUI

/// Settings screen for the dashboard's section order and visibility.
struct DashboardLayoutView: View {
    @EnvironmentObject private var settings: AppSettings

    var body: some View {
        List {
            Section {
                ForEach(settings.dashboardLayout.order) { section in
                    Toggle(section.label, isOn: visibility(of: section))
                }
                .onMove { settings.dashboardLayout.order.move(fromOffsets: $0, toOffset: $1) }
            } footer: {
                Text("Drag to reorder. Switch a section off to hide it. Agent key warnings always show first.")
            }

            Section {
                Button("Reset to default") { settings.dashboardLayout = .standard }
                    .disabled(settings.dashboardLayout == .standard)
            }
        }
        // Always in edit mode so the drag handles are visible without an Edit tap.
        .environment(\.editMode, .constant(.active))
        .navigationTitle("Dashboard Layout")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func visibility(of section: DashboardSection) -> Binding<Bool> {
        Binding(
            get: { !settings.dashboardLayout.hidden.contains(section) },
            set: { visible in
                if visible {
                    settings.dashboardLayout.hidden.remove(section)
                } else {
                    settings.dashboardLayout.hidden.insert(section)
                }
            }
        )
    }
}
