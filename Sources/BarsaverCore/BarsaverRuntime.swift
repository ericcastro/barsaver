import AppKit

@MainActor
public final class BarsaverRuntime: NSObject {
    private let contentController: MarqueeContentController
    private let holdToClickBinding: HoldToClickBinding?
    private var overlays: [CGDirectDisplayID: OverlayController] = [:]
    private var selectedDisplayIDs: Set<CGDirectDisplayID> = []
    private var mouseTracker: MouseTracker?
    private var hasStarted = false

    public var selection: DisplaySelection {
        didSet {
            guard hasStarted else { return }
            applyCurrentDisplaySelection()
            mouseTracker?.reset(for: DisplayManager.selectedDisplays(for: selection))
        }
    }

    public init(configuration: MarqueeConfigurationFile, selection: DisplaySelection) throws {
        self.selection = selection
        self.contentController = MarqueeContentController(blocks: try MarqueePluginRegistryValue().makeBlocks(from: configuration.blocks))
        self.holdToClickBinding = InteractionConfiguration.binding(for: configuration.settings["hold_to_click_key"])
        super.init()
    }

    public func start() {
        guard !hasStarted else { return }
        hasStarted = true

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleScreenParametersChanged),
            name: NSApplication.didChangeScreenParametersNotification,
            object: nil
        )

        applyCurrentDisplaySelection()
        startMouseTracking()
        contentController.start { [weak self] snapshot in
            self?.overlays.values.forEach { $0.updateSnapshot(snapshot) }
        }
    }

    public func stop() {
        guard hasStarted else { return }
        hasStarted = false
        NotificationCenter.default.removeObserver(self)
        mouseTracker?.stop()
        overlays.values.forEach { $0.close() }
        overlays.removeAll()
        selectedDisplayIDs.removeAll()
    }

    @objc
    private func handleScreenParametersChanged() {
        applyCurrentDisplaySelection()
        mouseTracker?.reset(for: DisplayManager.selectedDisplays(for: selection))
    }

    private func applyCurrentDisplaySelection() {
        let selectedDisplays = DisplayManager.selectedDisplays(for: selection)
        let nextIDs = Set(selectedDisplays.map(\.displayID))

        for display in selectedDisplays {
            if let overlay = overlays[display.displayID] {
                overlay.refresh(display: display)
                overlay.setHoldToClickBinding(holdToClickBinding)
                overlay.onInteractiveSegmentHover = { [weak self] blockID, active in
                    self?.contentController.setManualReadMode(for: blockID, active: active)
                }
            } else {
                let overlay = OverlayController(display: display)
                overlay.setHoldToClickBinding(holdToClickBinding)
                overlay.onInteractiveSegmentHover = { [weak self] blockID, active in
                    self?.contentController.setManualReadMode(for: blockID, active: active)
                }
                overlays[display.displayID] = overlay
            }
        }

        let removedIDs = selectedDisplayIDs.subtracting(nextIDs)
        for displayID in removedIDs {
            overlays[displayID]?.close()
            overlays.removeValue(forKey: displayID)
        }

        selectedDisplayIDs = nextIDs
    }

    private func startMouseTracking() {
        mouseTracker = MouseTracker(holdToClickBinding: holdToClickBinding, holdHandler: { [weak self] active in
            self?.overlays.values.forEach { $0.setHoldToClickActive(active) }
        }) { [weak self] displayID, shouldReveal in
            self?.overlays[displayID]?.setRevealed(shouldReveal, animated: true)
        }
        mouseTracker?.start()
        mouseTracker?.reset(for: DisplayManager.selectedDisplays(for: selection))
    }
}
