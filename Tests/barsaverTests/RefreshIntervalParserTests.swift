import XCTest
@testable import barsaver

final class RefreshIntervalParserTests: XCTestCase {
    func testParsesSecondsMinutesHoursAndRawNumbers() {
        XCTAssertEqual(RefreshIntervalParser.parse("30s"), 30)
        XCTAssertEqual(RefreshIntervalParser.parse("5m"), 300)
        XCTAssertEqual(RefreshIntervalParser.parse("2h"), 7200)
        XCTAssertEqual(RefreshIntervalParser.parse("45"), 45)
    }

    func testRejectsUnknownSuffixes() {
        XCTAssertNil(RefreshIntervalParser.parse("10d"))
        XCTAssertNil(RefreshIntervalParser.parse("abc"))
        XCTAssertNil(RefreshIntervalParser.parse(nil))
    }
}
