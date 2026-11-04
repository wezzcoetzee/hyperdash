import XCTest
@testable import Hyperdash

final class WalletSortTests: XCTestCase {

    private func data(value: Double, dayPnl: [Double] = []) throws -> WalletData {
        let perps = try JSONDecoder().decode(PerpsState.self, from: Data(#"""
        {
          "marginSummary": {"accountValue": "\#(value)", "totalNtlPos": "0", "totalRawUsd": "0", "totalMarginUsed": "0"},
          "crossMarginSummary": {"accountValue": "\#(value)", "totalNtlPos": "0", "totalRawUsd": "0", "totalMarginUsed": "0"},
          "crossMaintenanceMarginUsed": "0", "withdrawable": "0", "assetPositions": []
        }
        """#.utf8))
        let snapshot = WalletSnapshot(perps: perps, spot: SpotState(balances: []), openOrders: [],
                                      mids: [:], spotMidKeys: [:])
        let history = dayPnl.enumerated().map {
            PortfolioPoint(date: Date(timeIntervalSince1970: Double($0.offset)), value: $0.element)
        }
        let window = PortfolioWindow(accountValueHistory: [], pnlHistory: history)
        return WalletData(snapshot: snapshot, portfolio: PortfolioResponse(windows: ["day": window]))
    }

    private let a = Wallet(name: "A", address: "0xa")
    private let b = Wallet(name: "B", address: "0xb")
    private let c = Wallet(name: "C", address: "0xc")

    func testCustomKeepsStoredOrder() throws {
        let wallets = [a, b, c]
        let cache = [a.id: try data(value: 1), b.id: try data(value: 3), c.id: try data(value: 2)]
        XCTAssertEqual(WalletSort.custom.sorted(wallets, data: cache), wallets)
    }

    func testValueSortsDescendingWithUnloadedLast() throws {
        let cache = [a.id: try data(value: 10), c.id: try data(value: 30)]
        XCTAssertEqual(WalletSort.value.sorted([a, b, c], data: cache).map(\.name), ["C", "A", "B"])
    }

    func testDayChangeSortsByPercentAndTiesKeepCustomOrder() throws {
        let cache = [
            a.id: try data(value: 110, dayPnl: [0, 10]),   // +10%
            b.id: try data(value: 105, dayPnl: [0, 5]),    // +5%
            c.id: try data(value: 220, dayPnl: [0, 20])    // +10%
        ]
        XCTAssertEqual(WalletSort.dayChange.sorted([a, b, c], data: cache).map(\.name), ["A", "C", "B"])
    }
}
