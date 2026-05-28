import Foundation

struct MarqueeSnapshot {
    let text: String
    let segments: [MarqueeSegment]
}

final class MarqueeContentController {
    private let blocks: [MarqueeBlock]
    private lazy var blocksByID = Dictionary(uniqueKeysWithValues: blocks.map { ($0.id, $0) })
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
        let snapshot = Self.makeSnapshot(from: blocks.map(\.currentSegment))

        Task { @MainActor [updateHandler] in
            updateHandler?(snapshot)
        }
    }

    static func makeSnapshot(from segments: [MarqueeSegment]) -> MarqueeSnapshot {
        let nonEmptySegments = segments.filter { !$0.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

        return MarqueeSnapshot(
            text: nonEmptySegments.isEmpty ? "barsaver" : nonEmptySegments.map(\.text).joined(separator: "   •   "),
            segments: nonEmptySegments.isEmpty ? [MarqueeSegment(blockID: UUID(), prefixText: nil, text: "barsaver", actionURL: nil, slotWidth: nil, allowsInnerScroll: false, innerScrollPause: nil)] : nonEmptySegments
        )
    }

    func setManualReadMode(for blockID: UUID?, active: Bool) {
        guard let blockID, let block = blocksByID[blockID] as? ManualReadModeControllable else {
            return
        }
        block.setManualReadMode(active)
    }
}
