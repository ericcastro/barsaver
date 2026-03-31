import Foundation

struct CLIOptions {
    enum DisplaySelection: Equatable {
        case all
        case external
        case indices(Set<Int>)
    }

    let shouldListDisplays: Bool
    let selection: DisplaySelection
    let configPath: String?
}

enum CLIParserError: LocalizedError {
    case missingDisplaySelection
    case missingConfigPath
    case invalidDisplaySelection(String)
    case invalidIndex(String)
    case unsupportedArgument(String)

    var errorDescription: String? {
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

enum CLIParser {
    static let usage = """
    barsaver examples:
      barsaver --list-displays
      barsaver --displays external
      barsaver --displays 1,2
      barsaver --config ~/barsaver.conf --displays all
    """

    static func parse(arguments: [String]) throws -> CLIOptions {
        var shouldListDisplays = false
        var selection: CLIOptions.DisplaySelection = .all
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
                selection = try parseDisplaySelection(value)
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

        return CLIOptions(shouldListDisplays: shouldListDisplays, selection: selection, configPath: configPath)
    }

    private static func parseDisplaySelection(_ rawValue: String) throws -> CLIOptions.DisplaySelection {
        let value = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)

        switch value {
        case "all":
            return .all
        case "external":
            return .external
        default:
            let indices = try Set(value.split(separator: ",").map { token -> Int in
                let trimmed = token.trimmingCharacters(in: .whitespacesAndNewlines)
                guard let index = Int(trimmed), index >= 0 else {
                    throw CLIParserError.invalidIndex(trimmed)
                }
                return index
            })

            guard !indices.isEmpty else {
                throw CLIParserError.invalidDisplaySelection(rawValue)
            }

            return .indices(indices)
        }
    }
}
