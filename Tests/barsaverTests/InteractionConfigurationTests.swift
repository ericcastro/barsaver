import AppKit
import XCTest
@testable import BarsaverCore

final class InteractionConfigurationTests: XCTestCase {
    func testMapsKnownModifierNames() {
        XCTAssertEqual(InteractionConfiguration.binding(for: "option"), .modifier(.option))
        XCTAssertEqual(InteractionConfiguration.binding(for: "cmd"), .modifier(.command))
        XCTAssertEqual(InteractionConfiguration.binding(for: "ctrl"), .modifier(.control))
        XCTAssertEqual(InteractionConfiguration.binding(for: "shift"), .modifier(.shift))
    }

    func testDefaultsToEscapeAndRejectsUnknownValues() {
        XCTAssertEqual(InteractionConfiguration.binding(for: nil), .keyCode(53))
        XCTAssertEqual(InteractionConfiguration.binding(for: "escape"), .keyCode(53))
        XCTAssertNil(InteractionConfiguration.binding(for: "banana"))
    }
}
