import XCTest
@testable import BarsaverCore

final class MarqueeContentControllerTests: XCTestCase {
    func testBuildsSnapshotFromNonEmptySegments() {
        let snapshot = MarqueeContentController.makeSnapshot(from: [
            MarqueeSegment(prefixText: nil, text: "barsaver", actionURL: nil, slotWidth: nil, allowsInnerScroll: false, innerScrollPause: nil),
            MarqueeSegment(prefixText: nil, text: "   ", actionURL: nil, slotWidth: nil, allowsInnerScroll: false, innerScrollPause: nil),
            MarqueeSegment(prefixText: "BBC", text: "Headline", actionURL: nil, slotWidth: 360, allowsInnerScroll: true, innerScrollPause: 0.9)
        ])

        XCTAssertEqual(snapshot.segments.count, 2)
        XCTAssertEqual(snapshot.segments[0].text, "barsaver")
        XCTAssertEqual(snapshot.segments[1].prefixText, "BBC")
    }

    func testBuildsFallbackSnapshotWhenAllSegmentsAreEmpty() {
        let snapshot = MarqueeContentController.makeSnapshot(from: [
            MarqueeSegment(prefixText: nil, text: " ", actionURL: nil, slotWidth: nil, allowsInnerScroll: false, innerScrollPause: nil)
        ])

        XCTAssertEqual(snapshot.segments.count, 1)
        XCTAssertEqual(snapshot.segments[0].text, "barsaver")
    }
}
