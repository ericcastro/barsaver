import Foundation

public enum DisplaySelection: Equatable {
    case all
    case external
    case indices(Set<Int>)
}

public enum DisplaySelectionParser {
    public static func parse(_ rawValue: String) throws -> DisplaySelection {
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

    public static func parseOptional(_ rawValue: String?) throws -> DisplaySelection? {
        guard let rawValue, !rawValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return nil
        }
        return try parse(rawValue)
    }
}

public enum DisplaySelectionLabeler {
    public static func label(for selection: DisplaySelection) -> String {
        switch selection {
        case .all:
            return "All Displays"
        case .external:
            return "External Displays"
        case .indices(let indices):
            let sorted = indices.sorted().map(String.init).joined(separator: ", ")
            return "Displays \(sorted)"
        }
    }
}
