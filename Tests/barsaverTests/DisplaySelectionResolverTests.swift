import CoreGraphics
import XCTest
@testable import barsaver

final class DisplaySelectionResolverTests: XCTestCase {
    private let displays = [
        DisplayInfo(index: 0, displayID: 101, frame: CGRect(x: 0, y: 0, width: 100, height: 100), isMain: true),
        DisplayInfo(index: 1, displayID: 102, frame: CGRect(x: 100, y: 0, width: 100, height: 100), isMain: false),
        DisplayInfo(index: 2, displayID: 103, frame: CGRect(x: 200, y: 0, width: 100, height: 100), isMain: false)
    ]

    func testSelectsAllDisplays() {
        XCTAssertEqual(DisplaySelectionResolver.select(.all, from: displays).map(\.displayID), [101, 102, 103])
    }

    func testSelectsExternalDisplays() {
        XCTAssertEqual(DisplaySelectionResolver.select(.external, from: displays).map(\.displayID), [102, 103])
    }

    func testSelectsSpecificIndices() {
        XCTAssertEqual(DisplaySelectionResolver.select(.indices([2, 0]), from: displays).map(\.displayID), [101, 103])
    }
}
