import XCTest
@testable import Hyperdash

final class SideExposureTests: XCTestCase {

    func testCombinedSumsNotionalAndCounts() {
        let a = SideExposure(
            long: .init(notional: 100, count: 1),
            short: .init(notional: 50, count: 1)
        )
        let b = SideExposure(
            long: .init(notional: 300, count: 2),
            short: .init(notional: 50, count: 1)
        )

        let combined = SideExposure.combined([a, b])

        XCTAssertEqual(combined.long.notional, 400)
        XCTAssertEqual(combined.long.count, 3)
        XCTAssertEqual(combined.short.notional, 100)
        XCTAssertEqual(combined.short.count, 2)
        XCTAssertEqual(combined.total, 500)
        XCTAssertEqual(combined.longShare, 0.8)
    }
}
