import Foundation

enum RefreshIntervalParser {
    static func parse(_ value: String?) -> TimeInterval? {
        guard let value, !value.isEmpty else {
            return nil
        }

        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if let seconds = TimeInterval(trimmed) {
            return seconds
        }

        let digits = trimmed.prefix { $0.isNumber }
        let suffix = trimmed.dropFirst(digits.count)
        guard let amount = TimeInterval(digits), !suffix.isEmpty else {
            return nil
        }

        switch suffix {
        case "s":
            return amount
        case "m":
            return amount * 60
        case "h":
            return amount * 3600
        default:
            return nil
        }
    }
}
