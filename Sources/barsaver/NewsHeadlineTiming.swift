import AppKit
import Foundation

enum NewsHeadlineTiming {
    static func displayDuration(
        text: String,
        slotWidth: CGFloat,
        font: NSFont,
        allowsInnerScroll: Bool,
        innerScrollPause: TimeInterval,
        postScrollPause: TimeInterval,
        scrollSpeed: CGFloat
    ) -> TimeInterval {
        let attributes: [NSAttributedString.Key: Any] = [.font: font]
        let textWidth = ceil((text as NSString).size(withAttributes: attributes).width)

        guard allowsInnerScroll, textWidth > slotWidth else {
            return postScrollPause
        }

        let fadeWidth = min(18, max(8, slotWidth * 0.08))
        let travelDistance = max(0, textWidth - slotWidth + (fadeWidth * 2))
        let travelDuration = max(1.8, TimeInterval(travelDistance / scrollSpeed))
        return innerScrollPause + travelDuration + postScrollPause
    }
}
