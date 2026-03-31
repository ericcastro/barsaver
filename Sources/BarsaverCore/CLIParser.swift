import Foundation

public struct CLIOptions {
    public let shouldListDisplays: Bool
    public let selectionOverride: DisplaySelection?
    public let configPath: String?

    public init(shouldListDisplays: Bool, selectionOverride: DisplaySelection?, configPath: String?) {
        self.shouldListDisplays = shouldListDisplays
        self.selectionOverride = selectionOverride
        self.configPath = configPath
    }
}

public enum CLIParserError: LocalizedError {
    case missingDisplaySelection
    case missingConfigPath
    case invalidDisplaySelection(String)
    case invalidIndex(String)
    case unsupportedArgument(String)

    public var errorDescription: String? {
        switch self {
        case .missingDisplaySelection:
            return "Missing value for --displays."
        case .missingConfigPath:
            return "Missing value for --config."
        case .invalidDisplaySelection(let value):
            return "Invalid display selection '\(value)'. Use all, external, or a comma-separated list of indices."
        case .invalidIndex(let value):
            return "Invalid display index '\(value)'."
        case .unsupportedArgument(let value):
            return "Unsupported argument '\(value)'."
        }
    }
}

public enum CLIParser {
    public static let usage = """
    barsaver examples:
      barsaver --list-displays
      barsaver --displays external
      barsaver --displays 1,2
      barsaver --config ~/barsaver.yaml --displays all
    """

    public static func parse(arguments: [String]) throws -> CLIOptions {
        var shouldListDisplays = false
        var selectionOverride: DisplaySelection?
        var configPath: String?

        var iterator = arguments.makeIterator()
        while let argument = iterator.next() {
            switch argument {
            case "--list-displays":
                shouldListDisplays = true
            case "--displays":
                guard let value = iterator.next() else {
                    throw CLIParserError.missingDisplaySelection
                }
                selectionOverride = try DisplaySelectionParser.parse(value)
            case "--config":
                guard let value = iterator.next() else {
                    throw CLIParserError.missingConfigPath
                }
                configPath = value
            case "--help", "-h":
                print(usage)
                Foundation.exit(EXIT_SUCCESS)
            default:
                throw CLIParserError.unsupportedArgument(argument)
            }
        }

        return CLIOptions(shouldListDisplays: shouldListDisplays, selectionOverride: selectionOverride, configPath: configPath)
    }
}
