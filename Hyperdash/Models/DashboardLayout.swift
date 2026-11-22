import Foundation

/// Agent-key warnings are deliberately not a section: they always sit on top
/// so a lapsed key can't be hidden away.
enum DashboardSection: String, CaseIterable, Identifiable {
    case summary, pnlLeaders, spotHoldings, positions, openInterest, accountValueChart, pnlChart

    var id: String { rawValue }

    var label: String {
        switch self {
        case .summary: "Total balance"
        case .pnlLeaders: "PnL leaders"
        case .spotHoldings: "Spot holdings"
        case .positions: "Positions"
        case .openInterest: "Open interest"
        case .accountValueChart: "Account value chart"
        case .pnlChart: "PnL chart"
        }
    }
}

struct DashboardLayout: Equatable {
    var order: [DashboardSection]
    var hidden: Set<DashboardSection>

    static let standard = DashboardLayout(order: DashboardSection.allCases, hidden: [])

    var visible: [DashboardSection] { order.filter { !hidden.contains($0) } }

    /// Rebuilds a layout from stored raw values. Unknown or repeated entries are
    /// dropped, and sections added since the order was saved join at the end.
    init(storedOrder: [String], storedHidden: [String]) {
        var seen = Set<DashboardSection>()
        let known = storedOrder.compactMap(DashboardSection.init(rawValue:)).filter { seen.insert($0).inserted }
        self.init(order: known + DashboardSection.allCases.filter { !seen.contains($0) },
                  hidden: Set(storedHidden.compactMap(DashboardSection.init(rawValue:))))
    }

    init(order: [DashboardSection], hidden: Set<DashboardSection>) {
        self.order = order
        self.hidden = hidden
    }
}
