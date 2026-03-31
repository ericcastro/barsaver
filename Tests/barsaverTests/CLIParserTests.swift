import XCTest
@testable import barsaver

final class CLIParserTests: XCTestCase {
    func testParsesListDisplaysAndExternalSelection() throws {
        let options = try CLIParser.parse(arguments: ["--list-displays", "--displays", "external"])
        XCTAssertTrue(options.shouldListDisplays)
        XCTAssertEqual(options.selection, .external)
        XCTAssertNil(options.configPath)
    }

    func testParsesIndicesAndConfigPath() throws {
        let options = try CLIParser.parse(arguments: ["--config", "~/barsaver.conf", "--displays", "1,3"])
        XCTAssertEqual(options.selection, .indices([1, 3]))
        XCTAssertEqual(options.configPath, "~/barsaver.conf")
    }

    func testRejectsInvalidIndex() {
        XCTAssertThrowsError(try CLIParser.parse(arguments: ["--displays", "abc"])) { error in
            XCTAssertEqual((error as? CLIParserError)?.errorDescription, CLIParserError.invalidIndex("abc").errorDescription)
        }
    }
}
