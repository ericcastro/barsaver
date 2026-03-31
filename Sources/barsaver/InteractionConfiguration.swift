import AppKit

enum InteractionConfiguration {
    static func modifierFlags(for value: String?) -> NSEvent.ModifierFlags? {
        guard let value else {
            return .option
        }

        switch value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
        case "option", "alt":
            return .option
        case "command", "cmd":
            return .command
        case "control", "ctrl":
            return .control
        case "shift":
            return .shift
        case "capslock", "caps":
            return .capsLock
        case "fn", "function":
            return .function
        default:
            return nil
        }
    }
}
