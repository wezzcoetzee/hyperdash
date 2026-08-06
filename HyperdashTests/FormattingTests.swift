import XCTest
@testable import Hyperdash

final class FormattingTests: XCTestCase {

    func testAbbreviatedUSDShortensAxisScaleValues() {
        XCTAssertEqual(Format.abbreviatedUSD(0), "$0")
        XCTAssertEqual(Format.abbreviatedUSD(750), "$750")
        XCTAssertEqual(Format.abbreviatedUSD(1_500), "$1.5K")
        XCTAssertEqual(Format.abbreviatedUSD(25_000), "$25K")
        XCTAssertEqual(Format.abbreviatedUSD(75_000), "$75K")
        XCTAssertEqual(Format.abbreviatedUSD(1_200_000), "$1.2M")
        XCTAssertEqual(Format.abbreviatedUSD(48_000_000), "$48M")
        XCTAssertEqual(Format.abbreviatedUSD(2_400_000_000), "$2.4B")
    }

    func testAbbreviatedUSDSignsNegatives() {
        XCTAssertEqual(Format.abbreviatedUSD(-25_000), "-$25K")
        XCTAssertEqual(Format.abbreviatedUSD(-400), "-$400")
    }

    func testAbbreviatedUSDKeepsCentsOnSmallOddAmounts() {
        XCTAssertEqual(Format.abbreviatedUSD(4.25), "$4.25")
        XCTAssertEqual(Format.abbreviatedUSD(4), "$4")
    }
}
