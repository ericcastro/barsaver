import CoreGraphics

enum MouseRevealPolicy {
    static func shouldReveal(
        mouseLocation: CGPoint,
        displayFrame: CGRect,
        wasRevealed: Bool,
        holdToClickActive: Bool,
        threshold: CGFloat,
        hysteresis: CGFloat
    ) -> Bool {
        guard !holdToClickActive else {
            return false
        }

        let isWithinDisplayWidth = mouseLocation.x >= displayFrame.minX && mouseLocation.x <= displayFrame.maxX
        let distanceFromTop = displayFrame.maxY - mouseLocation.y

        if isWithinDisplayWidth && distanceFromTop <= 0 {
            return true
        }

        guard isWithinDisplayWidth, mouseLocation.y >= displayFrame.minY else {
            return false
        }

        let enterThreshold = threshold
        let exitThreshold = threshold + hysteresis
        return wasRevealed ? distanceFromTop <= exitThreshold : distanceFromTop <= enterThreshold
    }
}
