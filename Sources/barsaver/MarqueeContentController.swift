import Foundation

struct MarqueeSnapshot {
    let text: String
    let segments: [MarqueeSegment]
}

final class MarqueeContentController {
    private let blocks: [MarqueeBlock]
    private var updateHandler: (@MainActor (MarqueeSnapshot) -> Void)?

    init(blocks: [MarqueeBlock]) {
        self.blocks = blocks
    }

    func start(updateHandler: @escaping @MainActor (MarqueeSnapshot) -> Void) {
        self.updateHandler = updateHandler
        blocks.forEach { block in
            block.start { [weak self] in
                self?.publish()
            }
        }
        publish()
    }

    private func publish() {
        let segments = blocks
            .map(\.currentSegment)
            .filter { !$0.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

        let snapshot = MarqueeSnapshot(
            text: segments.isEmpty ? "barsaver" : segments.map(\.text).joined(separator: "   •   "),
            segments: segments.isEmpty ? [MarqueeSegment(prefixText: nil, text: "barsaver", actionURL: nil, slotWidth: nil, allowsInnerScroll: false, innerScrollPause: nil)] : segments
        )

        Task { @MainActor [updateHandler] in
            updateHandler?(snapshot)
        }
    }
}
