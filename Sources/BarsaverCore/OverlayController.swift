import AppKit

@MainActor
final class OverlayController {
    private let opacity: CGFloat
    private let contentView = ContentView(frame: .zero)
    private var window: NSPanel?
    private var isRevealed = false
    private var display: DisplayInfo
    var onInteractiveSegmentHover: ((UUID?, Bool) -> Void)?

    init(display: DisplayInfo, opacity: CGFloat = 1.0) {
        self.display = display
        self.opacity = opacity
        createWindowIfPossible()
    }

    func refresh(display: DisplayInfo) {
        self.display = display

        guard let window else {
            createWindowIfPossible()
            return
        }

        let frame = DisplayManager.overlayFrame(for: display)
        window.setFrame(frame, display: true)
        contentView.prepareForDisplay(size: frame.size)
    }

    func close() {
        window?.close()
        window = nil
    }

    func updateSnapshot(_ snapshot: MarqueeSnapshot) {
        contentView.update(snapshot: snapshot)
    }

    func setHoldToClickBinding(_ binding: HoldToClickBinding?) {
        contentView.setHoldToClickBinding(binding)
    }

    func setHoldToClickActive(_ active: Bool) {
        contentView.setHoldToClickActive(active)
    }

    func setRevealed(_ revealed: Bool, animated: Bool) {
        guard let window, revealed != isRevealed else {
            return
        }

        isRevealed = revealed
        window.ignoresMouseEvents = revealed

        let targetAlpha: CGFloat = revealed ? 0 : opacity
        if animated {
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.2
                context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
                window.animator().alphaValue = targetAlpha
            }
        } else {
            window.alphaValue = targetAlpha
        }
    }

    private func createWindowIfPossible() {
        let frame = DisplayManager.overlayFrame(for: display)
        let panel = NSPanel(
            contentRect: frame,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.level = .screenSaver
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = false
        panel.collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary]
        panel.hidesOnDeactivate = false
        panel.becomesKeyOnlyIfNeeded = false
        panel.ignoresMouseEvents = false
        panel.isMovable = false
        panel.isExcludedFromWindowsMenu = true
        panel.alphaValue = opacity
        panel.contentView = contentView
        contentView.prepareForDisplay(size: frame.size)
        contentView.onOpenURL = { url in
            NSWorkspace.shared.open(url)
        }
        contentView.onInteractiveSegmentHover = { [weak self] blockID, active in
            self?.onInteractiveSegmentHover?(blockID, active)
        }
        panel.orderFrontRegardless()
        window = panel
    }
}
