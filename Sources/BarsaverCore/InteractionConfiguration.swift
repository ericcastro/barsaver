import AppKit

public enum HoldToClickBinding: Equatable {
    case modifier(NSEvent.ModifierFlags)
    case keyCode(UInt16)
}

public enum InteractionConfiguration {
    public static func binding(for value: String?) -> HoldToClickBinding? {
        guard let value else {
            return .keyCode(53)
        }

        switch value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
        case "escape", "esc":
            return .keyCode(53)
        case "option", "alt":
            return .modifier(.option)
        case "command", "cmd":
            return .modifier(.command)
        case "control", "ctrl":
            return .modifier(.control)
        case "shift":
            return .modifier(.shift)
        case "capslock", "caps":
            return .modifier(.capsLock)
        case "fn", "function":
            return .modifier(.function)
        default:
            return nil
        }
    }
}
