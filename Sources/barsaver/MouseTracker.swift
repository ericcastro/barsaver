import AppKit

final class MouseTracker {
    typealias UpdateHandler = (_ displayID: CGDirectDisplayID, _ shouldReveal: Bool) -> Void
    typealias HoldHandler = (_ active: Bool) -> Void

    private let threshold: CGFloat
    private let hysteresis: CGFloat
    private let holdToClickModifier: NSEvent.ModifierFlags?
    private let updateHandler: UpdateHandler
    private let holdHandler: HoldHandler?
    private var mouseMonitor: Any?
    private var flagsMonitor: Any?
    private var displayStates: [CGDirectDisplayID: Bool] = [:]
    private var currentModifierFlags: NSEvent.ModifierFlags = []

    init(
        threshold: CGFloat = 40,
        hysteresis: CGFloat = 12,
        holdToClickModifier: NSEvent.ModifierFlags?,
        holdHandler: HoldHandler? = nil,
        updateHandler: @escaping UpdateHandler
    ) {
        self.threshold = threshold
        self.hysteresis = hysteresis
        self.holdToClickModifier = holdToClickModifier
        self.holdHandler = holdHandler
        self.updateHandler = updateHandler
    }

    func start() {
        guard mouseMonitor == nil, flagsMonitor == nil else {
            return
        }

        mouseMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.mouseMoved, .leftMouseDragged, .rightMouseDragged, .otherMouseDragged]) { [weak self] _ in
            self?.evaluateMouseLocation()
        }
        flagsMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.flagsChanged]) { [weak self] event in
            self?.currentModifierFlags = event.modifierFlags
            self?.holdHandler?(self?.isHoldToClickActive ?? false)
            self?.evaluateMouseLocation()
        }
        holdHandler?(isHoldToClickActive)
        evaluateMouseLocation()
    }

    func stop() {
        if let mouseMonitor {
            NSEvent.removeMonitor(mouseMonitor)
        }
        if let flagsMonitor {
            NSEvent.removeMonitor(flagsMonitor)
        }
        mouseMonitor = nil
        flagsMonitor = nil
    }

    func reset(for displays: [DisplayInfo]) {
        let validIDs = Set(displays.map(\.displayID))
        displayStates = displayStates.filter { validIDs.contains($0.key) }
        evaluateMouseLocation()
    }

    private func evaluateMouseLocation() {
        let holdToClickActive = isHoldToClickActive
        let mouseLocation = NSEvent.mouseLocation

        for display in DisplayManager.currentDisplays() {
            let wasRevealed = displayStates[display.displayID] ?? false

            let shouldReveal = MouseRevealPolicy.shouldReveal(
                mouseLocation: mouseLocation,
                displayFrame: display.frame,
                wasRevealed: wasRevealed,
                holdToClickActive: holdToClickActive,
                threshold: threshold,
                hysteresis: hysteresis
            )

            if shouldReveal != wasRevealed {
                displayStates[display.displayID] = shouldReveal
                updateHandler(display.displayID, shouldReveal)
            } else if displayStates[display.displayID] == nil {
                displayStates[display.displayID] = shouldReveal
                updateHandler(display.displayID, shouldReveal)
            }
        }
    }

    private var isHoldToClickActive: Bool {
        holdToClickModifier.map { currentModifierFlags.contains($0) } ?? false
    }
}
