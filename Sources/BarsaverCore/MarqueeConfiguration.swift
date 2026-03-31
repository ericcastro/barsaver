import Foundation
import Yams

public struct MarqueeBlockDefinition: Sendable {
    public let type: String
    public let settings: [String: String]

    public init(type: String, settings: [String : String]) {
        self.type = type
        self.settings = settings
    }
}

public struct MarqueeConfigurationFile: Sendable {
    public let settings: [String: String]
    public let blocks: [MarqueeBlockDefinition]

    public init(settings: [String : String], blocks: [MarqueeBlockDefinition]) {
        self.settings = settings
        self.blocks = blocks
    }
}

enum MarqueeConfigurationError: LocalizedError {
    case missingPath(String)
    case invalidYAML(String)
    case invalidRootObject
    case invalidBlock(Int)

    var errorDescription: String? {
        switch self {
        case .missingPath(let path):
            return "Configuration file not found at '\(path)'."
        case .invalidYAML(let description):
            return "Invalid YAML configuration: \(description)"
        case .invalidRootObject:
            return "Configuration root must be a YAML mapping."
        case .invalidBlock(let index):
            return "Block at index \(index) must be a YAML mapping with a 'type' field."
        }
    }
}

public enum MarqueeConfiguration {
    static let defaultSettings: [String: String] = [
        "hold_to_click_key": "option",
        "display_selection": "all"
    ]

    static let defaultBlocks: [MarqueeBlockDefinition] = [
        MarqueeBlockDefinition(type: "static_text", settings: ["value": "barsaver"]),
        MarqueeBlockDefinition(type: "timestamp", settings: ["format": "HH:mm"]),
        MarqueeBlockDefinition(type: "static_text", settings: ["value": "OLED-safe menubar"])
    ]

    public static func load(from path: String?) throws -> MarqueeConfigurationFile {
        if let path {
            let url = URL(fileURLWithPath: NSString(string: path).expandingTildeInPath)
            guard FileManager.default.fileExists(atPath: url.path) else {
                throw MarqueeConfigurationError.missingPath(url.path)
            }

            let contents = try String(contentsOf: url, encoding: .utf8)
            return try parse(contents: contents)
        }

        for candidate in ["barsaver.yaml", "barsaver.yml"] {
            let localDefault = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
                .appendingPathComponent(candidate)
            if FileManager.default.fileExists(atPath: localDefault.path) {
                let contents = try String(contentsOf: localDefault, encoding: .utf8)
                return try parse(contents: contents)
            }
        }

        return MarqueeConfigurationFile(settings: defaultSettings, blocks: defaultBlocks)
    }

    static func parseForTesting(_ contents: String) throws -> MarqueeConfigurationFile {
        try parse(contents: contents)
    }

    public static func displaySelection(from configuration: MarqueeConfigurationFile) throws -> DisplaySelection {
        try DisplaySelectionParser.parseOptional(configuration.settings["display_selection"]) ?? .all
    }

    public static func save(_ configuration: MarqueeConfigurationFile, to url: URL) throws {
        let yaml = render(configuration)
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try yaml.write(to: url, atomically: true, encoding: .utf8)
    }

    private static func parse(contents: String) throws -> MarqueeConfigurationFile {
        let loaded: Any
        do {
            loaded = try Yams.load(yaml: contents) as Any
        } catch {
            throw MarqueeConfigurationError.invalidYAML(error.localizedDescription)
        }

        guard let root = loaded as? [String: Any] else {
            throw MarqueeConfigurationError.invalidRootObject
        }

        var settings = defaultSettings
        for (key, value) in root where key != "blocks" {
            settings[key] = stringify(value)
        }

        let definitions: [MarqueeBlockDefinition]
        if let blockItems = root["blocks"] as? [Any] {
            definitions = try blockItems.enumerated().map { index, item in
                guard var block = item as? [String: Any], let type = block.removeValue(forKey: "type").map(stringify), !type.isEmpty else {
                    throw MarqueeConfigurationError.invalidBlock(index)
                }

                let settings = Dictionary(uniqueKeysWithValues: block.map { key, value in
                    (key, stringify(value))
                })
                return MarqueeBlockDefinition(type: type, settings: settings)
            }
        } else {
            definitions = defaultBlocks
        }

        return MarqueeConfigurationFile(settings: settings, blocks: definitions.isEmpty ? defaultBlocks : definitions)
    }

    private static func stringify(_ value: Any) -> String {
        switch value {
        case let string as String:
            return string
        case let number as NSNumber:
            return number.stringValue
        case let bool as Bool:
            return bool ? "true" : "false"
        default:
            return String(describing: value)
        }
    }

    private static func render(_ configuration: MarqueeConfigurationFile) -> String {
        var lines: [String] = []

        for key in orderedTopLevelKeys(configuration.settings) {
            guard let value = configuration.settings[key] else { continue }
            lines.append("\(key): \(yamlScalar(value))")
        }

        if !lines.isEmpty {
            lines.append("")
        }

        lines.append("blocks:")
        for block in configuration.blocks {
            lines.append("  - type: \(yamlScalar(block.type))")
            for key in orderedBlockKeys(for: block) {
                guard let value = block.settings[key] else { continue }
                lines.append("    \(key): \(yamlScalar(value))")
            }
        }

        return lines.joined(separator: "\n") + "\n"
    }

    private static func orderedTopLevelKeys(_ settings: [String: String]) -> [String] {
        let preferred = ["hold_to_click_key", "display_selection"]
        let remainder = settings.keys
            .filter { !preferred.contains($0) }
            .sorted()
        return preferred.filter { settings[$0] != nil } + remainder
    }

    private static func orderedBlockKeys(for block: MarqueeBlockDefinition) -> [String] {
        let preferred: [String]
        switch block.type {
        case "static_text":
            preferred = ["value"]
        case "timestamp":
            preferred = ["format", "value"]
        case "news_headline":
            preferred = ["prefix", "rss_source", "refresh_interval", "cycle_interval", "slot_width", "inner_scroll_pause"]
        case "crypto_ticker":
            preferred = ["symbol", "refresh_interval"]
        case "stock_ticker":
            preferred = ["symbol", "refresh_interval", "api_key"]
        default:
            preferred = []
        }

        let remainder = block.settings.keys
            .filter { !preferred.contains($0) }
            .sorted()
        return preferred.filter { block.settings[$0] != nil } + remainder
    }

    private static func yamlScalar(_ value: String) -> String {
        let plainAllowed = !value.isEmpty &&
            value.range(of: #"^[A-Za-z0-9_./:+,\-]+$"#, options: .regularExpression) != nil &&
            !["true", "false", "null", "~"].contains(value.lowercased())

        if plainAllowed {
            return value
        }

        let escaped = value
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
        return "\"\(escaped)\""
    }
}
