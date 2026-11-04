import XCTest
@testable import Hyperdash

final class PositionGroupTests: XCTestCase {

    private func positionJSON(coin: String, size: Double, pnl: Double, liq: Double?) -> String {
        """
        {"type": "oneWay", "position": {
          "coin": "\(coin)", "szi": "\(size)", "entryPx": "100", "positionValue": "\(abs(size) * 100)",
          "unrealizedPnl": "\(pnl)", "returnOnEquity": "0", "liquidationPx": \(liq.map { "\"\($0)\"" } ?? "null"),
          "marginUsed": "10", "maxLeverage": 20,
          "leverage": {"type": "cross", "value": 10},
          "cumFunding": {"allTime": "0", "sinceOpen": "0", "sinceChange": "0"}}}
        """
    }

    private func perps(_ positions: [String]) throws -> PerpsState {
        try JSONDecoder().decode(PerpsState.self, from: Data("""
        {
          "marginSummary": {"accountValue": "100", "totalNtlPos": "0", "totalRawUsd": "0", "totalMarginUsed": "0"},
          "crossMarginSummary": {"accountValue": "100", "totalNtlPos": "0", "totalRawUsd": "0", "totalMarginUsed": "0"},
          "crossMaintenanceMarginUsed": "0", "withdrawable": "0",
          "assetPositions": [\(positions.joined(separator: ","))]
        }
        """.utf8))
    }

    /// Every coin is marked at 100 on the core DEX and on each builder DEX.
    private func data(core: [String], builder: [String: [String]] = [:]) throws -> WalletData {
        let marks = ["ETH": 100.0, "BTC": 100.0, "SOL": 100.0]
        var mids = ["": marks]
        for dex in builder.keys { mids[dex] = marks }
        let snapshot = WalletSnapshot(
            perps: try perps(core),
            builderPerps: try builder.mapValues(perps),
            spot: SpotState(balances: []), openOrders: [],
            mids: mids, spotMidKeys: [:])
        return WalletData(snapshot: snapshot, portfolio: PortfolioResponse(windows: [:]))
    }

    private let a = Wallet(name: "A", address: "0xa")
    private let b = Wallet(name: "B", address: "0xb")

    func testGroupsSameCoinAndSideAcrossWallets() throws {
        let cache = [
            a.id: try data(core: [positionJSON(coin: "ETH", size: 2, pnl: 10, liq: 90)]),
            b.id: try data(core: [positionJSON(coin: "ETH", size: 3, pnl: -4, liq: 50)])
        ]
        let groups = PositionGroup.groups(wallets: [a, b], data: cache)
        XCTAssertEqual(groups.count, 1)
        XCTAssertEqual(groups[0].totalSize, 5, accuracy: 1e-9)
        XCTAssertEqual(groups[0].unrealizedPnl, 6, accuracy: 1e-9)
        XCTAssertEqual(groups[0].walletCount, 2)
        XCTAssertEqual(try XCTUnwrap(groups[0].nearestLiquidationPct), 10, accuracy: 1e-9)
    }

    func testSidesAndDexesStaySeparate() throws {
        let cache = [
            a.id: try data(core: [positionJSON(coin: "ETH", size: 1, pnl: 0, liq: nil),
                                  positionJSON(coin: "BTC", size: -1, pnl: 0, liq: nil)],
                           builder: ["xyz": [positionJSON(coin: "ETH", size: 1, pnl: 0, liq: nil)]]),
            b.id: try data(core: [positionJSON(coin: "ETH", size: -1, pnl: 0, liq: nil)])
        ]
        let keys = PositionGroup.groups(wallets: [a, b], data: cache).map(\.key)
        XCTAssertEqual(Set(keys), [
            PositionGroupKey(dex: "", coin: "ETH", isLong: true),
            PositionGroupKey(dex: "", coin: "ETH", isLong: false),
            PositionGroupKey(dex: "", coin: "BTC", isLong: false),
            PositionGroupKey(dex: "xyz", coin: "ETH", isLong: true)
        ])
    }

    func testSortsNearestLiquidationFirstAndSkipsUnloadedWallets() throws {
        let cache = [
            a.id: try data(core: [positionJSON(coin: "ETH", size: 1, pnl: 0, liq: 50),
                                  positionJSON(coin: "BTC", size: 1, pnl: 0, liq: 95),
                                  positionJSON(coin: "SOL", size: 1, pnl: 0, liq: nil)])
        ]
        let groups = PositionGroup.groups(wallets: [a, b], data: cache)
        XCTAssertEqual(groups.map(\.key.coin), ["BTC", "ETH", "SOL"])
    }
}
