import AppKit
import QuartzCore

@MainActor
final class ContentView: NSView {
    private struct SegmentVisual {
        let prefixLayer: CATextLayer
        let slotLayer: CALayer
        let textLayer: CATextLayer
    }

    private struct InnerScrollLayout {
        let startX: CGFloat
        let endX: CGFloat
        let pauseDuration: TimeInterval
        let travelDuration: TimeInterval
    }

    private let backgroundLayer = CALayer()
    private let marqueeViewportLayer = CALayer()
    private let marqueeContainerLayer = CALayer()
    private let marqueeMaskLayer = CAGradientLayer()
    private let separator = "   •   "
    private let font = NSFont.systemFont(ofSize: 12, weight: .medium)
    private let textColor = NSColor.white.withAlphaComponent(0.92)
    private let linkColor = NSColor.systemYellow
    private let hoverLinkColor = NSColor.systemCyan
    private let marqueeSpeed: CGFloat = 36
    private var currentSnapshot = MarqueeSnapshot(text: "barsaver", segments: [MarqueeSegment(blockID: UUID(), prefixText: nil, text: "barsaver", actionURL: nil, slotWidth: nil, allowsInnerScroll: false, innerScrollPause: nil)])
    private var segmentVisuals: [SegmentVisual] = []
    private var separatorLayers: [CATextLayer] = []
    private var innerScrollLayouts: [InnerScrollLayout?] = []
    private var segmentURLs: [URL?] = []
    private var marqueeWidth: CGFloat = 0
    private var marqueeOffsetX: CGFloat = 0
    private var marqueePaused = false
    private var marqueeTimer: Timer?
    private var lastTickTime: CFTimeInterval?
    private var trackingArea: NSTrackingArea?
    private var mouseInside = false
    private var holdToClickActive = false
    private var hoveredSegmentIndex: Int?
    private var manualReadSegmentIndex: Int?
    var onOpenURL: ((URL) -> Void)?
    var onInteractiveSegmentHover: ((UUID?, Bool) -> Void)?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.masksToBounds = true

        backgroundLayer.backgroundColor = NSColor.black.cgColor
        layer?.addSublayer(backgroundLayer)

        marqueeViewportLayer.masksToBounds = true
        layer?.addSublayer(marqueeViewportLayer)

        marqueeContainerLayer.masksToBounds = false
        marqueeViewportLayer.addSublayer(marqueeContainerLayer)
        marqueeMaskLayer.colors = [
            NSColor.black.withAlphaComponent(0).cgColor,
            NSColor.black.cgColor,
            NSColor.black.cgColor,
            NSColor.black.withAlphaComponent(0).cgColor
        ]
        marqueeMaskLayer.startPoint = CGPoint(x: 0, y: 0.5)
        marqueeMaskLayer.endPoint = CGPoint(x: 1, y: 0.5)
        marqueeViewportLayer.mask = marqueeMaskLayer

        update(snapshot: currentSnapshot)
        startDriftAnimation()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        nil
    }

    override func layout() {
        super.layout()
        backgroundLayer.frame = bounds
        marqueeViewportLayer.frame = bounds
        marqueeMaskLayer.frame = bounds
        let parentFade = min(36, max(14, bounds.width * 0.025))
        let fadeRatio = bounds.width > 0 ? parentFade / bounds.width : 0.04
        marqueeMaskLayer.locations = [0, NSNumber(value: Double(fadeRatio)), NSNumber(value: Double(1 - fadeRatio)), 1]
        layoutSegments(animated: marqueeTimer != nil, changedIndices: Set(currentSnapshot.segments.indices), forceInnerRelayout: true)
        layoutMarquee(restartAnimation: marqueeOffsetX == 0)
        refreshTrackingArea()
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        updateContentsScale()
    }

    override func viewDidChangeBackingProperties() {
        super.viewDidChangeBackingProperties()
        updateContentsScale()
    }

    override func mouseDown(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        guard let url = actionURL(at: point) else {
            super.mouseDown(with: event)
            return
        }
        onOpenURL?(url)
    }

    override func mouseEntered(with event: NSEvent) {
        mouseInside = true
        updatePointerAndPauseState()
    }

    override func mouseExited(with event: NSEvent) {
        mouseInside = false
        updatePointerAndPauseState()
    }

    override func mouseMoved(with event: NSEvent) {
        updatePointerAndPauseState()
    }

    override func cursorUpdate(with event: NSEvent) {
        updatePointerAndPauseState()
    }

    func prepareForDisplay(size: CGSize) {
        frame = CGRect(origin: .zero, size: size)
        layoutSubtreeIfNeeded()
        backgroundLayer.frame = bounds
        layoutMarquee(restartAnimation: true)
    }

    func setHoldToClickBinding(_ binding: HoldToClickBinding?) {}

    func setHoldToClickActive(_ active: Bool) {
        holdToClickActive = active
        updatePointerAndPauseState()
    }

    func update(snapshot: MarqueeSnapshot) {
        let previousSnapshot = currentSnapshot
        currentSnapshot = snapshot
        ensureLayerCounts(for: snapshot.segments.count)
        segmentURLs = snapshot.segments.map(\.actionURL)

        let animated = marqueeTimer != nil
        let changedIndices = changedSegmentIndices(from: previousSnapshot, to: snapshot)

        applyText(to: snapshot)
        updateContentsScale()
        layoutSegments(animated: animated, changedIndices: changedIndices, forceInnerRelayout: false)
        layoutMarquee(restartAnimation: false, preferredMinX: marqueeOffsetX)
        updatePointerAndPauseState()
    }

    private func ensureLayerCounts(for segmentCount: Int) {
        while segmentVisuals.count < segmentCount {
            let prefixLayer = CATextLayer()
            prefixLayer.alignmentMode = .left
            prefixLayer.truncationMode = .none
            prefixLayer.isWrapped = false
            prefixLayer.font = font
            prefixLayer.fontSize = font.pointSize
            let slotLayer = CALayer()
            let textLayer = CATextLayer()
            textLayer.alignmentMode = .left
            textLayer.truncationMode = .none
            textLayer.isWrapped = false
            textLayer.font = font
            textLayer.fontSize = font.pointSize
            marqueeContainerLayer.addSublayer(prefixLayer)
            slotLayer.addSublayer(textLayer)
            marqueeContainerLayer.addSublayer(slotLayer)
            segmentVisuals.append(SegmentVisual(prefixLayer: prefixLayer, slotLayer: slotLayer, textLayer: textLayer))
        }
        while segmentVisuals.count > segmentCount {
            let visual = segmentVisuals.removeLast()
            visual.prefixLayer.removeFromSuperlayer()
            visual.slotLayer.removeFromSuperlayer()
        }

        if innerScrollLayouts.count < segmentCount {
            innerScrollLayouts.append(contentsOf: Array(repeating: nil, count: segmentCount - innerScrollLayouts.count))
        } else if innerScrollLayouts.count > segmentCount {
            innerScrollLayouts.removeLast(innerScrollLayouts.count - segmentCount)
        }

        let separatorCount = max(0, segmentCount - 1)
        while separatorLayers.count < separatorCount {
            let layer = CATextLayer()
            layer.alignmentMode = .left
            layer.truncationMode = .none
            layer.isWrapped = false
            layer.font = font
            layer.fontSize = font.pointSize
            marqueeContainerLayer.addSublayer(layer)
            separatorLayers.append(layer)
        }
        while separatorLayers.count > separatorCount {
            let layer = separatorLayers.removeLast()
            layer.removeFromSuperlayer()
        }
    }

    private func applyText(to snapshot: MarqueeSnapshot) {
        for (index, segment) in snapshot.segments.enumerated() {
            segmentVisuals[index].prefixLayer.string = attributedString(segment.prefixText.map { "\($0) " } ?? "", color: textColor)
            segmentVisuals[index].textLayer.string = attributedString(segment.text, color: textColorForSegment(at: index, segment: segment))
            if index < separatorLayers.count {
                separatorLayers[index].string = attributedString(separator, color: textColor)
            }
        }
    }

    private func attributedString(_ string: String, color: NSColor) -> NSAttributedString {
        NSAttributedString(string: string, attributes: [.font: font, .foregroundColor: color])
    }

    private func changedSegmentIndices(from oldSnapshot: MarqueeSnapshot, to newSnapshot: MarqueeSnapshot) -> Set<Int> {
        Set((0..<max(oldSnapshot.segments.count, newSnapshot.segments.count)).filter { index in
            let oldText = index < oldSnapshot.segments.count ? oldSnapshot.segments[index].text : nil
            let newText = index < newSnapshot.segments.count ? newSnapshot.segments[index].text : nil
            return oldText != newText
        })
    }

    private func layoutSegments(animated: Bool, changedIndices: Set<Int>, forceInnerRelayout: Bool) {
        let textHeight = font.ascender - font.descender + 2
        let y = max(0, floor((bounds.height - textHeight) / 2) - 1)
        let attributes: [NSAttributedString.Key: Any] = [.font: font]
        let separatorWidth = ceil((separator as NSString).size(withAttributes: attributes).width)
        let prefixSpacing: CGFloat = 8

        var cursor: CGFloat = 0
        CATransaction.begin()
        CATransaction.setAnimationDuration(animated ? 0.24 : 0)
        CATransaction.setAnimationTimingFunction(CAMediaTimingFunction(name: .easeInEaseOut))

        for index in currentSnapshot.segments.indices {
            let segment = currentSnapshot.segments[index]
            let visual = segmentVisuals[index]
            let prefixString = segment.prefixText.map { "\($0) " } ?? ""
            let prefixWidth = prefixString.isEmpty ? 0 : ceil((prefixString as NSString).size(withAttributes: attributes).width)
            visual.prefixLayer.frame = CGRect(x: cursor, y: y, width: prefixWidth, height: textHeight)
            cursor += prefixWidth
            if prefixWidth > 0 {
                cursor += prefixSpacing
            }
            let textWidth = ceil((segment.text as NSString).size(withAttributes: attributes).width)
            let slotWidth = max(segment.slotWidth ?? textWidth, min(textWidth, max(80, bounds.width * 0.2)))
            let shouldRelayoutInner =
                forceInnerRelayout ||
                changedIndices.contains(index) ||
                abs(visual.slotLayer.bounds.width - slotWidth) > 0.5 ||
                abs(visual.textLayer.bounds.width - textWidth) > 0.5

            visual.slotLayer.frame = CGRect(x: cursor, y: y, width: slotWidth, height: textHeight)
            if shouldRelayoutInner {
                layoutInnerText(
                    in: visual.slotLayer,
                    for: visual.textLayer,
                    textWidth: textWidth,
                    slotWidth: slotWidth,
                    shouldScroll: segment.allowsInnerScroll,
                    pauseDuration: segment.innerScrollPause ?? 0.7,
                    animated: animated,
                    changed: changedIndices.contains(index),
                    segmentIndex: index
                )
            } else {
                visual.textLayer.frame.size.height = max(1, textHeight)
            }
            cursor += slotWidth

            if index < separatorLayers.count {
                separatorLayers[index].frame = CGRect(x: cursor, y: y, width: separatorWidth, height: textHeight)
                cursor += separatorWidth
            }
        }

        CATransaction.commit()
        marqueeWidth = cursor
    }

    private func layoutInnerText(in slotLayer: CALayer, for textLayer: CATextLayer, textWidth: CGFloat, slotWidth: CGFloat, shouldScroll: Bool, pauseDuration: TimeInterval, animated: Bool, changed: Bool, segmentIndex: Int) {
        textLayer.removeAnimation(forKey: "innerMarquee")
        textLayer.removeAnimation(forKey: "innerReverseMarquee")
        textLayer.removeAnimation(forKey: "segmentFade")
        slotLayer.mask = nil
        textLayer.frame = CGRect(x: 0, y: 0, width: textWidth, height: max(1, textLayer.superlayer?.bounds.height ?? 1))
        innerScrollLayouts[segmentIndex] = nil

        if changed, animated {
            let fade = CATransition()
            fade.type = .fade
            fade.duration = 0.18
            fade.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            textLayer.add(fade, forKey: "segmentFade")
        }

        guard shouldScroll, textWidth > slotWidth else {
            applyInnerTranslation(0, to: textLayer)
            return
        }

        let fadeWidth = min(18, max(8, slotWidth * 0.08))
        let slotMask = CAGradientLayer()
        slotMask.colors = [
            NSColor.black.withAlphaComponent(0).cgColor,
            NSColor.black.cgColor,
            NSColor.black.cgColor,
            NSColor.black.withAlphaComponent(0).cgColor
        ]
        slotMask.startPoint = CGPoint(x: 0, y: 0.5)
        slotMask.endPoint = CGPoint(x: 1, y: 0.5)
        slotMask.frame = slotLayer.bounds
        let fadeRatio = slotWidth > 0 ? fadeWidth / slotWidth : 0.1
        slotMask.locations = [0, NSNumber(value: Double(fadeRatio)), NSNumber(value: Double(1 - fadeRatio)), 1]
        slotLayer.mask = slotMask

        let startX = fadeWidth
        let endX = -(textWidth - slotWidth + fadeWidth)
        let travelDistance = abs(endX - startX)
        let travelDuration = max(1.8, CFTimeInterval(travelDistance / 28))
        let layout = InnerScrollLayout(startX: startX, endX: endX, pauseDuration: pauseDuration, travelDuration: travelDuration)
        innerScrollLayouts[segmentIndex] = layout
        applyInnerTranslation(startX, to: textLayer)
        startForwardInnerMarquee(on: textLayer, layout: layout)
    }

    private func layoutMarquee(restartAnimation: Bool, preferredMinX: CGFloat? = nil) {
        guard bounds.width > 0, bounds.height > 0, marqueeWidth > 0 else {
            return
        }

        let startTranslationX: CGFloat
        if restartAnimation {
            startTranslationX = bounds.width
        } else if let preferredMinX {
            startTranslationX = preferredMinX <= -marqueeWidth ? bounds.width : min(preferredMinX, bounds.width)
        } else {
            startTranslationX = bounds.width
        }

        marqueeContainerLayer.frame = CGRect(x: startTranslationX, y: 0, width: marqueeWidth, height: marqueeViewportLayer.bounds.height)
        marqueeOffsetX = startTranslationX
        startMarqueeTimer()
    }

    private func startMarqueeTimer() {
        guard marqueeTimer == nil else { return }
        let timer = Timer(timeInterval: 1.0 / 60.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.tickMarquee()
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        marqueeTimer = timer
        lastTickTime = CACurrentMediaTime()
    }

    private func tickMarquee() {
        guard !marqueePaused, marqueeWidth > 0, bounds.width > 0 else {
            lastTickTime = CACurrentMediaTime()
            return
        }

        let currentTime = CACurrentMediaTime()
        let delta = max(0, currentTime - (lastTickTime ?? currentTime))
        lastTickTime = currentTime

        marqueeOffsetX -= marqueeSpeed * CGFloat(delta)
        if marqueeOffsetX <= -marqueeWidth {
            marqueeOffsetX = bounds.width
        }
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        marqueeContainerLayer.frame.origin.x = marqueeOffsetX
        CATransaction.commit()
    }

    private func actionURL(at point: CGPoint) -> URL? {
        for (index, visual) in segmentVisuals.enumerated() {
            let activeFrame = visual.slotLayer.frame.offsetBy(dx: marqueeOffsetX, dy: 0)
            if activeFrame.contains(point) {
                return segmentURLs[index]
            }
        }
        return nil
    }

    private func refreshTrackingArea() {
        if let trackingArea {
            removeTrackingArea(trackingArea)
        }
        let trackingArea = NSTrackingArea(rect: bounds, options: [.mouseEnteredAndExited, .mouseMoved, .activeAlways, .inVisibleRect, .cursorUpdate], owner: self, userInfo: nil)
        addTrackingArea(trackingArea)
        self.trackingArea = trackingArea
    }

    private func updatePointerAndPauseState() {
        let previousManualReadIndex = manualReadSegmentIndex
        let hoveredIndex: Int?
        if mouseInside, let window {
            let point = convert(window.mouseLocationOutsideOfEventStream, from: nil)
            hoveredIndex = hoveredSegmentIndex(at: point)
            if let hoveredIndex, currentSnapshot.segments[hoveredIndex].actionURL != nil {
                NSCursor.pointingHand.set()
            } else {
                NSCursor.arrow.set()
            }
        } else {
            hoveredIndex = nil
            NSCursor.arrow.set()
        }

        if hoveredSegmentIndex != hoveredIndex {
            hoveredSegmentIndex = hoveredIndex
            refreshSegmentColors()
        }

        updateManualReadMode(previousManualReadIndex: previousManualReadIndex)

        if !holdToClickActive, let previousManualReadIndex = manualReadSegmentIndex {
            setManualReadMode(active: false, forSegmentAt: previousManualReadIndex)
            manualReadSegmentIndex = nil
        }

        setMarqueePaused(mouseInside && holdToClickActive)
    }

    private func refreshSegmentColors() {
        for (index, segment) in currentSnapshot.segments.enumerated() {
            segmentVisuals[index].prefixLayer.string = attributedString(segment.prefixText.map { "\($0) " } ?? "", color: textColor)
            segmentVisuals[index].textLayer.string = attributedString(segment.text, color: textColorForSegment(at: index, segment: segment))
        }
    }

    private func textColorForSegment(at index: Int, segment: MarqueeSegment) -> NSColor {
        if hoveredSegmentIndex == index, segment.actionURL != nil {
            return hoverLinkColor
        }
        if segment.actionURL != nil, segment.allowsInnerScroll {
            return linkColor
        }
        return textColor
    }

    private func setMarqueePaused(_ paused: Bool) {
        marqueePaused = paused
        lastTickTime = CACurrentMediaTime()
    }

    private func updateContentsScale() {
        let scale = window?.screen?.backingScaleFactor ?? window?.backingScaleFactor ?? 2
        for visual in segmentVisuals {
            visual.prefixLayer.contentsScale = scale
            visual.textLayer.contentsScale = scale
        }
        for layer in separatorLayers {
            layer.contentsScale = scale
        }
    }

    private func startDriftAnimation() {
        let animation = CAKeyframeAnimation(keyPath: "transform.translation.y")
        animation.values = [0, 1, -1, 0]
        animation.keyTimes = [0, 0.33, 0.66, 1]
        animation.duration = 12
        animation.repeatCount = .infinity
        animation.isAdditive = true
        animation.timingFunctions = [
            CAMediaTimingFunction(name: .easeInEaseOut),
            CAMediaTimingFunction(name: .easeInEaseOut),
            CAMediaTimingFunction(name: .easeInEaseOut)
        ]
        layer?.add(animation, forKey: "drift")
    }

    private func hoveredSegmentIndex(at point: CGPoint) -> Int? {
        for (index, visual) in segmentVisuals.enumerated() {
            let activeFrame = visual.slotLayer.frame.offsetBy(dx: marqueeOffsetX, dy: 0)
            if activeFrame.contains(point) {
                return index
            }
        }
        return nil
    }

    private func updateManualReadMode(previousManualReadIndex: Int?) {
        let targetIndex: Int?
        if
            holdToClickActive,
            let hoveredSegmentIndex,
            currentSnapshot.segments.indices.contains(hoveredSegmentIndex),
            currentSnapshot.segments[hoveredSegmentIndex].allowsInnerScroll,
            currentSnapshot.segments[hoveredSegmentIndex].actionURL != nil
        {
            targetIndex = hoveredSegmentIndex
        } else {
            targetIndex = nil
        }

        if previousManualReadIndex != targetIndex, let previousManualReadIndex {
            setManualReadMode(active: false, forSegmentAt: previousManualReadIndex)
        }
        if manualReadSegmentIndex != targetIndex, let targetIndex {
            setManualReadMode(active: true, forSegmentAt: targetIndex)
        }
        manualReadSegmentIndex = targetIndex
    }

    private func setManualReadMode(active: Bool, forSegmentAt index: Int) {
        guard currentSnapshot.segments.indices.contains(index), segmentVisuals.indices.contains(index) else {
            return
        }
        let segment = currentSnapshot.segments[index]
        let textLayer = segmentVisuals[index].textLayer

        if active {
            onInteractiveSegmentHover?(segment.blockID, true)
            guard let layout = innerScrollLayouts[index] else { return }
            let currentX = currentInnerTranslation(for: textLayer)
            startReverseInnerMarquee(on: textLayer, from: currentX, to: layout.startX)
        } else {
            onInteractiveSegmentHover?(segment.blockID, false)
            guard let layout = innerScrollLayouts[index] else { return }
            applyInnerTranslation(layout.startX, to: textLayer)
            startForwardInnerMarquee(on: textLayer, layout: layout)
        }
    }

    private func startForwardInnerMarquee(on textLayer: CATextLayer, layout: InnerScrollLayout) {
        textLayer.removeAnimation(forKey: "innerReverseMarquee")
        textLayer.removeAnimation(forKey: "innerMarquee")
        let totalDuration = layout.pauseDuration + layout.travelDuration
        let startPauseRatio = layout.pauseDuration / totalDuration
        applyInnerTranslation(layout.endX, to: textLayer)
        let animation = CAKeyframeAnimation(keyPath: "transform.translation.x")
        animation.values = [layout.startX, layout.startX, layout.endX]
        animation.keyTimes = [0, NSNumber(value: startPauseRatio), 1]
        animation.duration = totalDuration
        animation.repeatCount = 1
        animation.isRemovedOnCompletion = false
        animation.fillMode = .forwards
        animation.timingFunctions = [
            CAMediaTimingFunction(name: .easeInEaseOut),
            CAMediaTimingFunction(name: .linear)
        ]
        textLayer.add(animation, forKey: "innerMarquee")
    }

    private func startReverseInnerMarquee(on textLayer: CATextLayer, from currentX: CGFloat, to startX: CGFloat) {
        textLayer.removeAnimation(forKey: "innerMarquee")
        textLayer.removeAnimation(forKey: "innerReverseMarquee")
        applyInnerTranslation(startX, to: textLayer)
        let distance = abs(currentX - startX)
        let duration = max(0.15, TimeInterval(distance / 40))
        let animation = CABasicAnimation(keyPath: "transform.translation.x")
        animation.fromValue = currentX
        animation.toValue = startX
        animation.duration = duration
        animation.isRemovedOnCompletion = false
        animation.fillMode = .forwards
        animation.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        textLayer.add(animation, forKey: "innerReverseMarquee")
    }

    private func applyInnerTranslation(_ translationX: CGFloat, to textLayer: CATextLayer) {
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        textLayer.setAffineTransform(CGAffineTransform(translationX: translationX, y: 0))
        CATransaction.commit()
    }

    private func currentInnerTranslation(for textLayer: CATextLayer) -> CGFloat {
        if let presentation = textLayer.presentation(),
           let value = presentation.value(forKeyPath: "transform.translation.x") as? NSNumber {
            return CGFloat(truncating: value)
        }
        return textLayer.affineTransform().tx
    }
}
