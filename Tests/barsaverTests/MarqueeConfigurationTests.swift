import XCTest
@testable import BarsaverCore

final class MarqueeConfigurationTests: XCTestCase {
    func testParsesSettingsAndBlocks() throws {
        let contents = """
        hold_to_click_key: command
        blocks:
          - type: static_text
            value: barsaver
          - type: news_headline
            prefix: BBC
            rss_source: https://example.com/feed.xml
            refresh_interval: 5m
        """

        let parsed = try MarqueeConfiguration.parseForTesting(contents)
        XCTAssertEqual(parsed.settings["hold_to_click_key"], "command")
        XCTAssertEqual(parsed.blocks.count, 2)
        XCTAssertEqual(parsed.blocks[0].type, "static_text")
        XCTAssertEqual(parsed.blocks[0].settings["value"], "barsaver")
        XCTAssertEqual(parsed.blocks[1].type, "news_headline")
        XCTAssertEqual(parsed.blocks[1].settings["prefix"], "BBC")
        XCTAssertEqual(parsed.blocks[1].settings["rss_source"], "https://example.com/feed.xml")
    }

    func testRejectsInvalidRootObject() {
        let contents = """
        - not
        - a
        - mapping
        """

        XCTAssertThrowsError(try MarqueeConfiguration.parseForTesting(contents)) { error in
            guard case MarqueeConfigurationError.invalidRootObject = error else {
                return XCTFail("Expected orphanedSetting error, got \(error)")
            }
        }
    }
}
