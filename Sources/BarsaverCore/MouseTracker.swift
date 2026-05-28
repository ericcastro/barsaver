import AppKit

final class MouseTracker {
    typealias UpdateHandler = (_ displayID: CGDirectDisplayID, _ shouldReveal: Bool) -> Void
    typealias HoldHandler = (_ active: Bool) -> Void

    private let threshold: CGFloat
    private let hysteresis: CGFloat
    private let holdToClickBinding: HoldToClickBinding?
    private let updateHandler: UpdateHandler
    private let holdHandler: HoldHandler?
    private var mouseMonitor: Any?
    private var flagsMonitor: Any?
    private var keyDownMonitor: Any?
    private var keyUpMonitor: Any?
    private var displayStates: [CGDirectDisplayID: Bool] = [:]
    private var currentModifierFlags: NSEvent.ModifierFlags = []
    private var pressedKeyCodes: Set<UInt16> = []

    init(
        threshold: CGFloat = 40,
        hysteresis: CGFloat = 12,
        holdToClickBinding: HoldToClickBinding?,
        holdHandler: HoldHandler? = nil,
        updateHandler: @escaping UpdateHandler
    ) {
        self.threshold = threshold
        self.hysteresis = hysteresis
        self.holdToClickBinding = holdToClickBinding
        self.holdHandler = holdHandler
        self.updateHandler = updateHandler
    }

    func start() {
        guard mouseMonitor == nil, flagsMonitor == nil, keyDownMonitor == nil, keyUpMonitor == nil else {
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
        keyDownMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.keyDown]) { [weak self] event in
            self?.pressedKeyCodes.insert(event.keyCode)
            self?.holdHandler?(self?.isHoldToClickActive ?? false)
            self?.evaluateMouseLocation()
        }
        keyUpMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.keyUp]) { [weak self] event in
            self?.pressedKeyCodes.remove(event.keyCode)
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
        if let keyDownMonitor {
            NSEvent.removeMonitor(keyDownMonitor)
        }
        if let keyUpMonitor {
            NSEvent.removeMonitor(keyUpMonitor)
        }
        mouseMonitor = nil
        flagsMonitor = nil
        keyDownMonitor = nil
        keyUpMonitor = nil
        pressedKeyCodes.removeAll()
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
        guard let holdToClickBinding else {
            return false
        }
        switch holdToClickBinding {
        case .modifier(let flags):
            return currentModifierFlags.contains(flags)
        case .keyCode(let keyCode):
            return pressedKeyCodes.contains(keyCode)
        }
    }
}
