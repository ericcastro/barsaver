enum DisplaySelectionResolver {
    static func select(_ selection: CLIOptions.DisplaySelection, from displays: [DisplayInfo]) -> [DisplayInfo] {
        switch selection {
        case .all:
            return displays
        case .external:
            return displays.filter { !$0.isMain }
        case .indices(let indices):
            return displays.filter { indices.contains($0.index) }
        }
    }
}
