import Foundation

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
    case invalidLine(String)
    case orphanedSetting(String)

    var errorDescription: String? {
        switch self {
        case .missingPath(let path):
            return "Configuration file not found at '\(path)'."
        case .invalidLine(let line):
            return "Invalid configuration line: \(line)"
        case .orphanedSetting(let line):
            return "Found a block setting without a preceding block: \(line)"
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

        let localDefault = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
            .appendingPathComponent("barsaver.conf")
        if FileManager.default.fileExists(atPath: localDefault.path) {
            let contents = try String(contentsOf: localDefault, encoding: .utf8)
            return try parse(contents: contents)
        }

        return MarqueeConfigurationFile(settings: defaultSettings, blocks: defaultBlocks)
    }

    private static func parse(contents: String) throws -> MarqueeConfigurationFile {
        var settings = defaultSettings
        var definitions: [MarqueeBlockDefinition] = []
        var currentType: String?
        var currentSettings: [String: String] = [:]

        func flushCurrent() {
            if let currentType {
                definitions.append(MarqueeBlockDefinition(type: currentType, settings: currentSettings))
            }
            currentType = nil
            currentSettings = [:]
        }

        for rawLine in contents.components(separatedBy: .newlines) {
            let trimmed = rawLine.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty || trimmed.hasPrefix("#") {
                continue
            }

            let isIndented = rawLine.first?.isWhitespace == true
            guard let colonIndex = trimmed.firstIndex(of: ":") else {
                throw MarqueeConfigurationError.invalidLine(rawLine)
            }

            let key = trimmed[..<colonIndex].trimmingCharacters(in: .whitespacesAndNewlines)
            let rawValue = trimmed[trimmed.index(after: colonIndex)...].trimmingCharacters(in: .whitespacesAndNewlines)
            let value = unquote(rawValue)

            if isIndented {
                guard currentType != nil else {
                    throw MarqueeConfigurationError.orphanedSetting(rawLine)
                }
                currentSettings[key] = value
            } else if key.hasPrefix("block_") {
                flushCurrent()
                currentType = String(key.dropFirst("block_".count))
                if !value.isEmpty {
                    currentSettings["value"] = value
                }
            } else {
                flushCurrent()
                settings[key] = value
            }
        }

        flushCurrent()

        return MarqueeConfigurationFile(
            settings: settings,
            blocks: definitions.isEmpty ? defaultBlocks : definitions
        )
    }

    private static func unquote(_ value: String) -> String {
        guard value.count >= 2 else {
            return value
        }
        if (value.hasPrefix("\"") && value.hasSuffix("\"")) || (value.hasPrefix("'") && value.hasSuffix("'")) {
            return String(value.dropFirst().dropLast())
        }
        return value
    }
}
