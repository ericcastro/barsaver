import AppKit
import XCTest
@testable import BarsaverCore

final class NewsHeadlineTimingTests: XCTestCase {
    private let font = NSFont.systemFont(ofSize: 12, weight: .medium)

    func testShortHeadlineUsesPostScrollPauseOnly() {
        let duration = NewsHeadlineTiming.displayDuration(
            text: "Short headline",
            slotWidth: 400,
            font: font,
            allowsInnerScroll: true,
            innerScrollPause: 0.9,
            postScrollPause: 10,
            scrollSpeed: 28
        )

        XCTAssertEqual(duration, 10, accuracy: 0.001)
    }

    func testLongHeadlineIncludesScrollTimeAndPause() {
        let duration = NewsHeadlineTiming.displayDuration(
            text: String(repeating: "Long headline ", count: 12),
            slotWidth: 220,
            font: font,
            allowsInnerScroll: true,
            innerScrollPause: 0.9,
            postScrollPause: 10,
            scrollSpeed: 28
        )

        XCTAssertGreaterThan(duration, 10.9)
    }

    func testNonScrollingSegmentUsesPostScrollPauseOnly() {
        let duration = NewsHeadlineTiming.displayDuration(
            text: String(repeating: "Long headline ", count: 12),
            slotWidth: 220,
            font: font,
            allowsInnerScroll: false,
            innerScrollPause: 0.9,
            postScrollPause: 10,
            scrollSpeed: 28
        )

        XCTAssertEqual(duration, 10, accuracy: 0.001)
    }
}
