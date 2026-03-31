import CoreGraphics
import XCTest
@testable import BarsaverCore

final class MouseRevealPolicyTests: XCTestCase {
    private let frame = CGRect(x: 0, y: 0, width: 1920, height: 1080)

    func testHoldToClickAlwaysKeepsOverlayHidden() {
        XCTAssertFalse(
            MouseRevealPolicy.shouldReveal(
                mouseLocation: CGPoint(x: 100, y: 1070),
                displayFrame: frame,
                wasRevealed: false,
                holdToClickActive: true,
                threshold: 40,
                hysteresis: 12
            )
        )
    }

    func testEnteringThresholdRevealsNearTopEdge() {
        XCTAssertTrue(
            MouseRevealPolicy.shouldReveal(
                mouseLocation: CGPoint(x: 100, y: 1050),
                displayFrame: frame,
                wasRevealed: false,
                holdToClickActive: false,
                threshold: 40,
                hysteresis: 12
            )
        )
    }

    func testTopEdgeStaysRevealedWhenPointerIsOnBorder() {
        XCTAssertTrue(
            MouseRevealPolicy.shouldReveal(
                mouseLocation: CGPoint(x: 100, y: 1080),
                displayFrame: frame,
                wasRevealed: false,
                holdToClickActive: false,
                threshold: 40,
                hysteresis: 12
            )
        )
    }

    func testHysteresisAllowsRevealedStateToPersistSlightlyFarther() {
        XCTAssertTrue(
            MouseRevealPolicy.shouldReveal(
                mouseLocation: CGPoint(x: 100, y: 1035),
                displayFrame: frame,
                wasRevealed: true,
                holdToClickActive: false,
                threshold: 40,
                hysteresis: 12
            )
        )
        XCTAssertFalse(
            MouseRevealPolicy.shouldReveal(
                mouseLocation: CGPoint(x: 100, y: 1020),
                displayFrame: frame,
                wasRevealed: true,
                holdToClickActive: false,
                threshold: 40,
                hysteresis: 12
            )
        )
    }
}
