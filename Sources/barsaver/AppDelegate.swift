import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let selection: CLIOptions.DisplaySelection
    private let contentController: MarqueeContentController
    private let holdToClickModifier: NSEvent.ModifierFlags?
    private var overlays: [CGDirectDisplayID: OverlayController] = [:]
    private var selectedDisplayIDs: Set<CGDirectDisplayID> = []
    private var mouseTracker: MouseTracker?
    private var signalSources: [DispatchSourceSignal] = []

    init(selection: CLIOptions.DisplaySelection, contentController: MarqueeContentController, holdToClickModifier: NSEvent.ModifierFlags?) {
        self.selection = selection
        self.contentController = contentController
        self.holdToClickModifier = holdToClickModifier
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.prohibited)
        installSignalHandlers()
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

    func applicationWillTerminate(_ notification: Notification) {
        mouseTracker?.stop()
        signalSources.forEach { $0.cancel() }
        overlays.values.forEach { $0.close() }
        overlays.removeAll()
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
                overlay.setHoldToClickModifier(holdToClickModifier)
            } else {
                let overlay = OverlayController(display: display)
                overlay.setHoldToClickModifier(holdToClickModifier)
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
        mouseTracker = MouseTracker(holdToClickModifier: holdToClickModifier, holdHandler: { [weak self] active in
            self?.overlays.values.forEach { $0.setHoldToClickActive(active) }
        }) { [weak self] displayID, shouldReveal in
            self?.overlays[displayID]?.setRevealed(shouldReveal, animated: true)
        }
        mouseTracker?.start()
        mouseTracker?.reset(for: DisplayManager.selectedDisplays(for: selection))
    }

    private func installSignalHandlers() {
        signal(SIGINT, SIG_IGN)
        signal(SIGTERM, SIG_IGN)

        for signalValue in [SIGINT, SIGTERM] {
            let source = DispatchSource.makeSignalSource(signal: signalValue, queue: .main)
            source.setEventHandler {
                NSApp.terminate(nil)
            }
            source.resume()
            signalSources.append(source)
        }
    }
}
