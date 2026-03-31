import XCTest
@testable import BarsaverCore

final class CLIParserTests: XCTestCase {
    func testParsesListDisplaysAndExternalSelection() throws {
        let options = try CLIParser.parse(arguments: ["--list-displays", "--displays", "external"])
        XCTAssertTrue(options.shouldListDisplays)
        XCTAssertEqual(options.selectionOverride, .external)
        XCTAssertNil(options.configPath)
    }

    func testParsesIndicesAndConfigPath() throws {
        let options = try CLIParser.parse(arguments: ["--config", "~/barsaver.yaml", "--displays", "1,3"])
        XCTAssertEqual(options.selectionOverride, .indices([1, 3]))
        XCTAssertEqual(options.configPath, "~/barsaver.yaml")
    }

    func testRejectsInvalidIndex() {
        XCTAssertThrowsError(try CLIParser.parse(arguments: ["--displays", "abc"])) { error in
            XCTAssertEqual((error as? CLIParserError)?.errorDescription, CLIParserError.invalidIndex("abc").errorDescription)
        }
    }
}
