import Foundation
import Yams

struct MarqueeBlockDefinition {
    let type: String
    let settings: [String: String]
}

struct MarqueeConfigurationFile {
    let settings: [String: String]
    let blocks: [MarqueeBlockDefinition]
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

enum MarqueeConfiguration {
    static let defaultSettings: [String: String] = [
        "hold_to_click_key": "option"
    ]

    static let defaultBlocks: [MarqueeBlockDefinition] = [
        MarqueeBlockDefinition(type: "static_text", settings: ["value": "barsaver"]),
        MarqueeBlockDefinition(type: "timestamp", settings: ["format": "HH:mm"]),
        MarqueeBlockDefinition(type: "static_text", settings: ["value": "OLED-safe menubar"])
    ]

    static func load(from path: String?) throws -> MarqueeConfigurationFile {
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
}
