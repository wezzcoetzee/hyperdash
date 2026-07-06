import XCTest
import SwiftUI
@testable import Hyperdash

@MainActor
final class AppLockTests: XCTestCase {

    func testUnlockFollowsAuthenticationResult() async {
        let granted = AppLock(authenticate: { _ in true })
        await granted.unlock()
        XCTAssertTrue(granted.isUnlocked)

        let denied = AppLock(authenticate: { _ in false })
        await denied.unlock()
        XCTAssertFalse(denied.isUnlocked)
    }

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
