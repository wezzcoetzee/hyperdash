import XCTest
@testable import Hyperdash

private struct StubVault: Vault {
    var key: String?

    func signingKey(for wallet: Wallet, reason: String) async throws -> String {
        guard let key else { throw VaultError.authenticationCancelled }
        return key
    }
}

final class TradeDeskTests: XCTestCase {

    private let wallet = Wallet(name: "Test", address: "0x7e5f4552091a69125d5dfcb7b8c2659029395bdf")
    private let agentKey = "0x0000000000000000000000000000000000000000000000000000000000000001"

    private func makeDesk(vault: Vault, exchangeFixture: String? = nil) -> TradeDesk {
        var transport = FixtureTransport(infoFixtures: [
            "meta": Fixtures.perpMeta,
            "spotMeta": Fixtures.spotMeta,
            "allMids": #"{"ETH": "2000.0", "@1": "0.5"}"#
        ])
        if let exchangeFixture { transport.exchangeFixture = exchangeFixture }
        let session = HyperliquidSession(network: .testnet, transport: transport)
        return TradeDesk(session: session, vault: vault, wallet: wallet)
    }

    private var longETH: Position {
        get throws {
            try JSONDecoder().decode(Position.self, from: Data(Fixtures.longETHPosition.utf8))
        }
    }

    func testPrepareClosePositionPricesAggressivelyThroughTheBook() async throws {
        let desk = makeDesk(vault: StubVault(key: agentKey))
        let plan = try await desk.prepare(.closePosition(try longETH))

        let expectedAction = TradeActions.orderAction(
            asset: AssetInfo(assetId: 0, szDecimals: 4, isSpot: false, midKey: "ETH"),
            isBuy: false,
            price: TradeActions.aggressivePrice(mark: 2000, isBuy: false),
            size: 1.5,
            reduceOnly: true
        )
        XCTAssertEqual(plan.actions[0].encoded(), expectedAction.encoded())

        let limitRow = try XCTUnwrap(plan.rows.first { $0.0 == "Limit (IOC)" })
        XCTAssertEqual(limitRow.1, Format.price(1900))
        XCTAssertNotNil(plan.warning)
    }

    func testPrepareCloseAllBatchesReduceOnlyOrderAndCancel() async throws {
        let desk = makeDesk(vault: StubVault(key: agentKey))
        let order = try JSONDecoder().decode(OpenOrder.self, from: Data(#"""
        {"coin": "ETH", "side": "B", "limitPx": "1500", "sz": "0.5", "oid": 42, "timestamp": 0}
        """#.utf8))

        let plan = try await desk.prepare(.closeAll(positions: [try longETH], orders: [order]))

        // Two signed submissions: a batched reduce-only order and a batched cancel.
        XCTAssertEqual(plan.actions.count, 2)

        let expectedOrder = TradeActions.ordersAction([
            TradeActions.orderEntry(
                asset: AssetInfo(assetId: 0, szDecimals: 4, isSpot: false, midKey: "ETH"),
                isBuy: false,
                price: TradeActions.aggressivePrice(mark: 2000, isBuy: false),
                size: 1.5,
                reduceOnly: true
            )
        ])
        XCTAssertEqual(plan.actions[0].encoded(), expectedOrder.encoded())

        let expectedCancel = TradeActions.cancelsAction([(assetId: 0, oid: 42)])
        XCTAssertEqual(plan.actions[1].encoded(), expectedCancel.encoded())
    }

    func testPrepareCloseAllWithOnlyOrdersSkipsOrderAction() async throws {
        let desk = makeDesk(vault: StubVault(key: agentKey))
        let order = try JSONDecoder().decode(OpenOrder.self, from: Data(#"""
        {"coin": "ETH", "side": "B", "limitPx": "1500", "sz": "0.5", "oid": 42, "timestamp": 0}
        """#.utf8))

        let plan = try await desk.prepare(.closeAll(positions: [], orders: [order]))

        XCTAssertEqual(plan.actions.count, 1)
        XCTAssertEqual(plan.actions[0].encoded(), TradeActions.cancelsAction([(assetId: 0, oid: 42)]).encoded())
    }

    func testExecuteSubmitsAndReturnsReceipt() async throws {
        let filled = #"""
        {"status": "ok", "response": {"type": "order", "data": {"statuses": [
          {"filled": {"oid": 77, "totalSz": "1.5", "avgPx": "1900.0"}}
        ]}}}
        """#
        let desk = makeDesk(vault: StubVault(key: agentKey), exchangeFixture: filled)
        let plan = try await desk.prepare(.closePosition(try longETH))

        let receipt = try await desk.execute(plan, reason: "Close LONG ETH")
        XCTAssertEqual(receipt.message, "Filled 1.5 @ \(Format.price(1900)).")
    }

    func testExecuteSurfacesExchangeRejection() async throws {
        let rejected = #"{"status": "err", "response": "Order must have minimum value of $10."}"#
        let desk = makeDesk(vault: StubVault(key: agentKey), exchangeFixture: rejected)
        let plan = try await desk.prepare(.closePosition(try longETH))

        do {
            _ = try await desk.execute(plan, reason: "Close LONG ETH")
            XCTFail("Expected rejection to throw")
        } catch let HyperliquidError.exchange(message) {
            XCTAssertEqual(message, "Order must have minimum value of $10.")
        }
    }

    func testExecuteWithoutAuthorizationNeverReachesTheWire() async throws {
        let desk = makeDesk(vault: StubVault(key: nil))
        let plan = try await desk.prepare(.closePosition(try longETH))

        do {
            _ = try await desk.execute(plan, reason: "Close LONG ETH")
            XCTFail("Expected vault denial to throw")
        } catch let error as VaultError {
            XCTAssertEqual(error.errorDescription, "Authentication cancelled.")
        }
    }

    // MARK: Opening, partial close, TP/SL

    private let eth = AssetInfo(assetId: 0, szDecimals: 4, isSpot: false, midKey: "ETH")

    private func trigger(_ json: String) throws -> OpenOrder {
        try JSONDecoder().decode(OpenOrder.self, from: Data(json.utf8))
    }

    func testPreparePartialCloseSendsTheFractionReduceOnly() async throws {
        let desk = makeDesk(vault: StubVault(key: agentKey))
        let plan = try await desk.prepare(.closePosition(try longETH, fraction: 0.5))

        let expected = TradeActions.orderAction(
            asset: eth, isBuy: false,
            price: TradeActions.aggressivePrice(mark: 2000, isBuy: false),
            size: 0.75, reduceOnly: true
        )
        XCTAssertEqual(plan.actions[0].encoded(), expected.encoded())
    }

    func testPrepareOpenMarketSetsLeverageThenAttachesTriggers() async throws {
        let desk = makeDesk(vault: StubVault(key: agentKey))
        let ticket = OrderTicket(coin: "ETH", isLong: true, kind: .market, notional: 1000, leverage: 5,
                                 takeProfitMove: 0.1, stopLossMove: 0.05)

        let plan = try await desk.prepare(.openPosition(ticket))

        XCTAssertEqual(plan.actions.count, 2)
        XCTAssertEqual(plan.actions[0].encoded(),
                       TradeActions.updateLeverageAction(assetId: 0, isCross: true, leverage: 5).encoded())

        // $1,000 at a 2,000 mark is 0.5 ETH. TP at +10%, SL at -5%, both sells closing the long.
        let expectedOrders = TradeActions.ordersAction([
            TradeActions.orderEntry(asset: eth, isBuy: true,
                                    price: TradeActions.aggressivePrice(mark: 2000, isBuy: true),
                                    size: 0.5, reduceOnly: false),
            TradeActions.orderEntry(asset: eth, isBuy: false,
                                    price: TradeActions.aggressivePrice(mark: 2200, isBuy: false),
                                    size: 0.5, reduceOnly: true,
                                    kind: .trigger(triggerPrice: 2200, isTakeProfit: true)),
            TradeActions.orderEntry(asset: eth, isBuy: false,
                                    price: TradeActions.aggressivePrice(mark: 1900, isBuy: false),
                                    size: 0.5, reduceOnly: true,
                                    kind: .trigger(triggerPrice: 1900, isTakeProfit: false))
        ], grouping: .normalTpsl)
        XCTAssertEqual(plan.actions[1].encoded(), expectedOrders.encoded())
    }

    func testPrepareOpenLimitRestsGtcAtTheLimitPrice() async throws {
        let desk = makeDesk(vault: StubVault(key: agentKey))
        let ticket = OrderTicket(coin: "ETH", isLong: false, kind: .limit(price: 2500), notional: 500, leverage: 2)

        let plan = try await desk.prepare(.openPosition(ticket))

        let expected = TradeActions.ordersAction([
            TradeActions.orderEntry(asset: eth, isBuy: false, price: 2500, size: 0.2,
                                    reduceOnly: false, kind: .gtc)
        ])
        XCTAssertEqual(plan.actions[1].encoded(), expected.encoded())
    }

    func testPrepareOpenRejectsLeverageAboveTheAssetMax() async throws {
        let desk = makeDesk(vault: StubVault(key: agentKey))
        let ticket = OrderTicket(coin: "ETH", isLong: true, kind: .market, notional: 1000, leverage: 51)

        do {
            _ = try await desk.prepare(.openPosition(ticket))
            XCTFail("Expected leverage above 50x to be rejected")
        } catch let HyperliquidError.exchange(message) {
            XCTAssertEqual(message, "Max leverage for ETH is 50x.")
        }
    }

    func testPrepareProtectionPlacesNewTriggersBeforeCancellingOld() async throws {
        let desk = makeDesk(vault: StubVault(key: agentKey))
        let old = try trigger(#"""
        {"coin": "ETH", "side": "A", "limitPx": "1500", "sz": "1.5", "oid": 9, "timestamp": 0,
         "orderType": "Stop Market", "reduceOnly": true, "isTrigger": true, "triggerPx": "1600"}
        """#)

        let plan = try await desk.prepare(.setProtection(try longETH, takeProfit: 2400, stopLoss: nil, replacing: [old]))

        XCTAssertEqual(plan.actions.count, 2)
        let expectedOrders = TradeActions.ordersAction([
            TradeActions.orderEntry(asset: eth, isBuy: false,
                                    price: TradeActions.aggressivePrice(mark: 2400, isBuy: false),
                                    size: 1.5, reduceOnly: true,
                                    kind: .trigger(triggerPrice: 2400, isTakeProfit: true))
        ], grouping: .positionTpsl)
        XCTAssertEqual(plan.actions[0].encoded(), expectedOrders.encoded())
        XCTAssertEqual(plan.actions[1].encoded(), TradeActions.cancelsAction([(assetId: 0, oid: 9)]).encoded())
    }

    func testPrepareProtectionWithNothingToChangeThrows() async throws {
        let desk = makeDesk(vault: StubVault(key: agentKey))
        do {
            _ = try await desk.prepare(.setProtection(try longETH, takeProfit: nil, stopLoss: nil, replacing: []))
            XCTFail("Expected an empty TP/SL change to be rejected")
        } catch HyperliquidError.exchange {}
    }
}
