import AppKit
import CoreGraphics

struct DisplayInfo: Hashable {
    let index: Int
    let displayID: CGDirectDisplayID
    let frame: CGRect
    let isMain: Bool

    var resolutionDescription: String {
        "\(Int(frame.width))x\(Int(frame.height))"
    }

    var originDescription: String {
        "(\(Int(frame.origin.x)), \(Int(frame.origin.y)))"
    }
}

enum DisplayManager {
    static func currentDisplays() -> [DisplayInfo] {
        let screenFrames = Dictionary(uniqueKeysWithValues: NSScreen.screens.map { screen in
            (displayID(for: screen), screen.frame)
        })

        return onlineDisplayIDs()
            .map { displayID in
                DisplayInfo(
                    index: 0,
                    displayID: displayID,
                    frame: screenFrames[displayID] ?? CGDisplayBounds(displayID),
                    isMain: displayID == CGMainDisplayID()
                )
            }
            .sorted { lhs, rhs in
                if lhs.frame.minX != rhs.frame.minX {
                    return lhs.frame.minX < rhs.frame.minX
                }
                if lhs.frame.minY != rhs.frame.minY {
                    return lhs.frame.minY < rhs.frame.minY
                }
                return lhs.displayID < rhs.displayID
            }
            .enumerated()
            .map { index, display in
                DisplayInfo(
                    index: index,
                    displayID: display.displayID,
                    frame: display.frame,
                    isMain: display.isMain
                )
            }
    }

    static func selectedDisplays(for selection: CLIOptions.DisplaySelection) -> [DisplayInfo] {
        let displays = currentDisplays()

        switch selection {
        case .all:
            return displays
        case .external:
            return displays.filter { !$0.isMain }
        case .indices(let indices):
            return displays.filter { indices.contains($0.index) }
        }
    }

    static func screen(for displayInfo: DisplayInfo) -> NSScreen? {
        NSScreen.screens.first { displayID(for: $0) == displayInfo.displayID }
    }

    static func overlayFrame(for displayInfo: DisplayInfo) -> CGRect {
        if let screen = screen(for: displayInfo) {
            let screenFrame = screen.frame
            let visibleFrame = screen.visibleFrame
            let measuredHeight = screenFrame.maxY - visibleFrame.maxY
            let height = max(measuredHeight, NSStatusBar.system.thickness)

            return CGRect(
                x: screenFrame.minX,
                y: screenFrame.maxY - height,
                width: screenFrame.width,
                height: height
            )
        }

        let height = NSStatusBar.system.thickness
        return CGRect(
            x: displayInfo.frame.minX,
            y: displayInfo.frame.maxY - height,
            width: displayInfo.frame.width,
            height: height
        )
    }

    static func printDisplays() {
        for display in currentDisplays() {
            let mainMarker = display.isMain ? " yes" : " no"
            print("[\(display.index)] \(display.resolutionDescription) origin \(display.originDescription) main:\(mainMarker)")
        }
    }

    private static func displayID(for screen: NSScreen) -> CGDirectDisplayID {
        let key = NSDeviceDescriptionKey("NSScreenNumber")
        return (screen.deviceDescription[key] as? NSNumber).map { CGDirectDisplayID($0.uint32Value) } ?? 0
    }

    private static func onlineDisplayIDs() -> [CGDirectDisplayID] {
        var count: UInt32 = 0
        CGGetOnlineDisplayList(0, nil, &count)
        guard count > 0 else {
            return []
        }

        var ids = Array(repeating: CGDirectDisplayID(), count: Int(count))
        CGGetOnlineDisplayList(count, &ids, &count)
        return Array(ids.prefix(Int(count)))
    }
}
