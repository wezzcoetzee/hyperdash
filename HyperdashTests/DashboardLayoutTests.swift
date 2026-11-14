import XCTest
@testable import Hyperdash

final class DashboardLayoutTests: XCTestCase {

    private func scratchDefaults() -> UserDefaults {
        let suite = "DashboardLayoutTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        addTeardownBlock { defaults.removePersistentDomain(forName: suite) }
        return defaults
    }

    /// A stored order survives app updates: unknown and repeated entries drop
    /// out, and sections it never saw join at the end.
    func testStoredOrderIsRepaired() {
        let layout = DashboardLayout(storedOrder: ["pnlChart", "retired", "summary", "pnlChart"],
                                     storedHidden: ["summary", "retired"])
        XCTAssertEqual(Array(layout.order.prefix(2)), [.pnlChart, .summary])
        XCTAssertEqual(Set(layout.order), Set(DashboardSection.allCases))
        XCTAssertEqual(layout.order.count, DashboardSection.allCases.count)
        XCTAssertEqual(layout.hidden, [.summary])
        XCTAssertFalse(layout.visible.contains(.summary))
    }

    func testLayoutPersistsAcrossLaunches() {
        let defaults = scratchDefaults()
        let shared = scratchDefaults()
        let settings = AppSettings(defaults: defaults, shared: shared)
        XCTAssertEqual(settings.dashboardLayout, .standard)

        settings.dashboardLayout.order.move(fromOffsets: [0], toOffset: DashboardSection.allCases.count)
        settings.dashboardLayout.hidden.insert(.openInterest)

        let relaunched = AppSettings(defaults: defaults, shared: shared).dashboardLayout
        XCTAssertEqual(relaunched, settings.dashboardLayout)
        XCTAssertEqual(relaunched.order.last, .summary)
    }
}
