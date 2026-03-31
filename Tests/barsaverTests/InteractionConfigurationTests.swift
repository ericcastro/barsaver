import AppKit
import XCTest
@testable import barsaver

final class InteractionConfigurationTests: XCTestCase {
    func testMapsKnownModifierNames() {
        XCTAssertEqual(InteractionConfiguration.modifierFlags(for: "option"), .option)
        XCTAssertEqual(InteractionConfiguration.modifierFlags(for: "cmd"), .command)
        XCTAssertEqual(InteractionConfiguration.modifierFlags(for: "ctrl"), .control)
        XCTAssertEqual(InteractionConfiguration.modifierFlags(for: "shift"), .shift)
    }

    func testDefaultsToOptionAndRejectsUnknownValues() {
        XCTAssertEqual(InteractionConfiguration.modifierFlags(for: nil), .option)
        XCTAssertNil(InteractionConfiguration.modifierFlags(for: "banana"))
    }
}
