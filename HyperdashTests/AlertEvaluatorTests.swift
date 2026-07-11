import XCTest
@testable import Hyperdash

final class AlertEvaluatorTests: XCTestCase {

    private func config(
        liquidation: Bool = false,
        threshold: Double = 10,
        alerts: [PriceAlert] = []
    ) -> AlertConfig {
        AlertConfig(liquidationEnabled: liquidation, liquidationThresholdPct: threshold, priceAlerts: alerts)
    }

    // MARK: - Liquidation

    func testLiquidationFiresWhenWithinThreshold() {
        let pos = AlertEvaluator.Position(walletName: "Main", coin: "BTC", liquidationPrice: 95, isLong: true)
        let out = AlertEvaluator.evaluate(.init(
            marks: ["BTC": 100],            // 5% away, threshold 10%
            positions: [pos],
            config: config(liquidation: true, threshold: 10),
            firedLiquidations: []
        ))
        XCTAssertEqual(out.events.count, 1)
        XCTAssertTrue(out.firedLiquidations.contains("Main|BTC"))
    }

    func testLiquidationDoesNotFireWhenComfortablyAway() {
        let pos = AlertEvaluator.Position(walletName: "Main", coin: "BTC", liquidationPrice: 50, isLong: true)
        let out = AlertEvaluator.evaluate(.init(
            marks: ["BTC": 100],            // 50% away
            positions: [pos],
            config: config(liquidation: true, threshold: 10),
            firedLiquidations: []
        ))
        XCTAssertTrue(out.events.isEmpty)
        XCTAssertTrue(out.firedLiquidations.isEmpty)
    }

    func testLiquidationDoesNotRepeatWhileStillFired() {
        let pos = AlertEvaluator.Position(walletName: "Main", coin: "BTC", liquidationPrice: 95, isLong: true)
        let out = AlertEvaluator.evaluate(.init(
            marks: ["BTC": 100],
            positions: [pos],
            config: config(liquidation: true, threshold: 10),
            firedLiquidations: ["Main|BTC"]     // already alerted
        ))
        XCTAssertTrue(out.events.isEmpty)
        XCTAssertTrue(out.firedLiquidations.contains("Main|BTC"))
    }

    func testLiquidationRearmsAfterRecoveryBeyondMargin() {
        let pos = AlertEvaluator.Position(walletName: "Main", coin: "BTC", liquidationPrice: 50, isLong: true)
        let out = AlertEvaluator.evaluate(.init(
            marks: ["BTC": 100],            // 50% away, well past threshold + margin
            positions: [pos],
            config: config(liquidation: true, threshold: 10),
            firedLiquidations: ["Main|BTC"]
        ))
        XCTAssertFalse(out.firedLiquidations.contains("Main|BTC"), "should re-arm once recovered")
    }

    func testLiquidationClearsFiredStateForClosedPosition() {
        let out = AlertEvaluator.evaluate(.init(
            marks: ["BTC": 100],
            positions: [],                  // position closed
            config: config(liquidation: true, threshold: 10),
            firedLiquidations: ["Main|BTC"]
        ))
        XCTAssertTrue(out.firedLiquidations.isEmpty)
    }

    func testLiquidationDisabledIgnored() {
        let pos = AlertEvaluator.Position(walletName: "Main", coin: "BTC", liquidationPrice: 95, isLong: true)
        let out = AlertEvaluator.evaluate(.init(
            marks: ["BTC": 100],
            positions: [pos],
            config: config(liquidation: false, threshold: 10),
            firedLiquidations: []
        ))
        XCTAssertTrue(out.events.isEmpty)
    }

    // MARK: - Price crossing

    func testPriceAlertArmsThenFiresOnCrossUp() {
        let alert = PriceAlert(coin: "ETH", target: 2000, direction: .above)

        // First eval below target: arms, does not fire.
        let armed = AlertEvaluator.evaluate(.init(
            marks: ["ETH": 1900],
            positions: [],
            config: config(alerts: [alert]),
            firedLiquidations: []
        ))
        XCTAssertTrue(armed.events.isEmpty)
        XCTAssertTrue(armed.priceAlerts[0].isArmed)
        XCTAssertNil(armed.priceAlerts[0].triggeredAt)

        // Second eval at/above target: fires.
        let fired = AlertEvaluator.evaluate(.init(
            marks: ["ETH": 2010],
            positions: [],
            config: config(alerts: armed.priceAlerts),
            firedLiquidations: []
        ))
        XCTAssertEqual(fired.events.count, 1)
        XCTAssertNotNil(fired.priceAlerts[0].triggeredAt)
    }

    func testPriceAlertSetAboveCurrentDoesNotFireImmediately() {
        // Target below current price with .above should not fire until price
        // dips below then crosses back up.
        let alert = PriceAlert(coin: "ETH", target: 2000, direction: .above)
        let out = AlertEvaluator.evaluate(.init(
            marks: ["ETH": 2100],           // already above, but never armed
            positions: [],
            config: config(alerts: [alert]),
            firedLiquidations: []
        ))
        XCTAssertTrue(out.events.isEmpty)
        XCTAssertFalse(out.priceAlerts[0].isArmed)
    }

    func testPriceAlertCrossDown() {
        let alert = PriceAlert(coin: "SOL", target: 100, direction: .below, isArmed: true)
        let out = AlertEvaluator.evaluate(.init(
            marks: ["SOL": 95],
            positions: [],
            config: config(alerts: [alert]),
            firedLiquidations: []
        ))
        XCTAssertEqual(out.events.count, 1)
        XCTAssertNotNil(out.priceAlerts[0].triggeredAt)
    }

    func testTriggeredPriceAlertDoesNotFireAgain() {
        let alert = PriceAlert(coin: "SOL", target: 100, direction: .below,
                               isArmed: true, triggeredAt: Date())
        let out = AlertEvaluator.evaluate(.init(
            marks: ["SOL": 90],
            positions: [],
            config: config(alerts: [alert]),
            firedLiquidations: []
        ))
        XCTAssertTrue(out.events.isEmpty)
    }

    func testDisabledPriceAlertIgnored() {
        let alert = PriceAlert(coin: "SOL", target: 100, direction: .below,
                               isEnabled: false, isArmed: true)
        let out = AlertEvaluator.evaluate(.init(
            marks: ["SOL": 90],
            positions: [],
            config: config(alerts: [alert]),
            firedLiquidations: []
        ))
        XCTAssertTrue(out.events.isEmpty)
    }
}
