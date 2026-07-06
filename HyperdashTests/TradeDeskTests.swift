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
        XCTAssertEqual(plan.action.encoded(), expectedAction.encoded())

        let limitRow = try XCTUnwrap(plan.rows.first { $0.0 == "Limit (IOC)" })
        XCTAssertEqual(limitRow.1, Format.price(1900))
        XCTAssertNotNil(plan.warning)
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
}
