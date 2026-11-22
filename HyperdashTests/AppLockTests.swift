import XCTest
import SwiftUI
@testable import Hyperdash

@MainActor
final class AppLockTests: XCTestCase {

    func testBackgroundingRelocks() async {
        let lock = AppLock(authenticate: { _ in true })
        await lock.unlock()

        lock.handleScenePhase(.inactive)
        XCTAssertTrue(lock.isUnlocked)

        lock.handleScenePhase(.background)
        XCTAssertFalse(lock.isUnlocked)

        lock.handleScenePhase(.active)
        XCTAssertFalse(lock.isUnlocked)
    }
}
