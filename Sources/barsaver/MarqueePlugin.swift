import Foundation

struct MarqueePluginContext {
    let refreshIntervalParser: (String?) -> TimeInterval?
}

struct MarqueeSegment {
    let prefixText: String?
    let text: String
    let actionURL: URL?
    let slotWidth: CGFloat?
    let allowsInnerScroll: Bool
    let innerScrollPause: TimeInterval?
}

protocol MarqueeBlockPlugin {
    var type: String { get }
    func makeBlock(from definition: MarqueeBlockDefinition, context: MarqueePluginContext) throws -> MarqueeBlock
}

protocol MarqueeBlock: AnyObject {
    var currentSegment: MarqueeSegment { get }
    func start(onUpdate: @escaping () -> Void)
    func stop()
}

enum MarqueePluginError: LocalizedError {
    case unsupportedBlock(String)
    case missingSetting(block: String, key: String)

    var errorDescription: String? {
        switch self {
        case .unsupportedBlock(let block):
            return "Unsupported block type '\(block)'."
        case .missingSetting(let block, let key):
            return "Block '\(block)' is missing required setting '\(key)'."
        }
    }
}

struct MarqueePluginRegistryValue {
    private let plugins: [String: any MarqueeBlockPlugin] = [
        "static_text": StaticTextPlugin(),
        "timestamp": TimestampPlugin(),
        "news_headline": NewsHeadlinePlugin(),
        "crypto_ticker": CryptoTickerPlugin()
    ]

    func makeBlocks(from definitions: [MarqueeBlockDefinition]) throws -> [MarqueeBlock] {
        let context = MarqueePluginContext(refreshIntervalParser: parseRefreshInterval(_:))
        return try definitions.map { definition in
            guard let plugin = plugins[definition.type] else {
                throw MarqueePluginError.unsupportedBlock(definition.type)
            }
            return try plugin.makeBlock(from: definition, context: context)
        }
    }

    private func parseRefreshInterval(_ value: String?) -> TimeInterval? {
        guard let value, !value.isEmpty else {
            return nil
        }

        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if let seconds = TimeInterval(trimmed) {
            return seconds
        }

        let digits = trimmed.prefix { $0.isNumber }
        let suffix = trimmed.dropFirst(digits.count)
        guard let amount = TimeInterval(digits), !suffix.isEmpty else {
            return nil
        }

        switch suffix {
        case "s":
            return amount
        case "m":
            return amount * 60
        case "h":
            return amount * 3600
        default:
            return nil
        }
    }
}

final class StaticTextBlock: MarqueeBlock {
    let currentSegment: MarqueeSegment

    init(text: String) {
        currentSegment = MarqueeSegment(prefixText: nil, text: text, actionURL: nil, slotWidth: nil, allowsInnerScroll: false, innerScrollPause: nil)
    }

    func start(onUpdate: @escaping () -> Void) {
        onUpdate()
    }

    func stop() {}
}

struct StaticTextPlugin: MarqueeBlockPlugin {
    let type = "static_text"

    func makeBlock(from definition: MarqueeBlockDefinition, context: MarqueePluginContext) throws -> MarqueeBlock {
        StaticTextBlock(text: definition.settings["value"] ?? "")
    }
}

final class TimestampBlock: MarqueeBlock {
    private let formatter: DateFormatter
    private var timer: Timer?
    private(set) var currentSegment = MarqueeSegment(prefixText: nil, text: "", actionURL: nil, slotWidth: nil, allowsInnerScroll: false, innerScrollPause: nil)

    init(format: String) {
        formatter = DateFormatter()
        formatter.dateFormat = format
    }

    func start(onUpdate: @escaping () -> Void) {
        refresh(onUpdate: onUpdate)
        timer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            self?.refresh(onUpdate: onUpdate)
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    private func refresh(onUpdate: @escaping () -> Void) {
        currentSegment = MarqueeSegment(prefixText: nil, text: formatter.string(from: Date()), actionURL: nil, slotWidth: nil, allowsInnerScroll: false, innerScrollPause: nil)
        onUpdate()
    }
}

struct TimestampPlugin: MarqueeBlockPlugin {
    let type = "timestamp"

    func makeBlock(from definition: MarqueeBlockDefinition, context: MarqueePluginContext) throws -> MarqueeBlock {
        TimestampBlock(format: definition.settings["format"] ?? definition.settings["value"] ?? "HH:mm")
    }
}

private struct RSSHeadline {
    let title: String
    let url: URL?
}

private final class RSSParserState: NSObject, XMLParserDelegate {
    private(set) var headlines: [RSSHeadline] = []
    private var currentElement = ""
    private var currentTitle = ""
    private var currentLink = ""
    private var insideItem = false

    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String : String] = [:]) {
        currentElement = elementName
        if elementName == "item" || elementName == "entry" {
            insideItem = true
            currentTitle = ""
            currentLink = ""
        }
        if insideItem, elementName == "link", let href = attributeDict["href"], !href.isEmpty {
            currentLink = href
        }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        guard insideItem else {
            return
        }
        if currentElement == "title" {
            currentTitle += string
        } else if currentElement == "link" {
            currentLink += string
        }
    }

    func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
        if elementName == "item" || elementName == "entry" {
            let title = currentTitle.trimmingCharacters(in: .whitespacesAndNewlines)
            if !title.isEmpty {
                headlines.append(RSSHeadline(title: title, url: URL(string: currentLink.trimmingCharacters(in: .whitespacesAndNewlines))))
            }
            insideItem = false
        }
        currentElement = ""
    }
}

final class NewsHeadlineBlock: MarqueeBlock {
    private let rssSource: URL
    private let refreshInterval: TimeInterval
    private let cycleInterval: TimeInterval
    private let prefix: String
    private let slotWidth: CGFloat
    private let innerScrollPause: TimeInterval
    private var fetchTimer: Timer?
    private var cycleTimer: Timer?
    private var onUpdate: (() -> Void)?
    private var headlines: [RSSHeadline] = []
    private var currentIndex = 0
    private(set) var currentSegment = MarqueeSegment(prefixText: nil, text: "Loading headlines", actionURL: nil, slotWidth: 360, allowsInnerScroll: true, innerScrollPause: 0.9)

    init(rssSource: URL, refreshInterval: TimeInterval, cycleInterval: TimeInterval, prefix: String, slotWidth: CGFloat, innerScrollPause: TimeInterval) {
        self.rssSource = rssSource
        self.refreshInterval = refreshInterval
        self.cycleInterval = cycleInterval
        self.prefix = prefix
        self.slotWidth = slotWidth
        self.innerScrollPause = innerScrollPause
        self.currentSegment = MarqueeSegment(prefixText: normalizedPrefix(), text: "Loading headlines", actionURL: nil, slotWidth: slotWidth, allowsInnerScroll: true, innerScrollPause: innerScrollPause)
    }

    func start(onUpdate: @escaping () -> Void) {
        self.onUpdate = onUpdate
        refresh()
        fetchTimer = Timer.scheduledTimer(withTimeInterval: refreshInterval, repeats: true) { [weak self] _ in
            self?.refresh()
        }
        cycleTimer = Timer.scheduledTimer(withTimeInterval: cycleInterval, repeats: true) { [weak self] _ in
            self?.advanceHeadline()
        }
    }

    func stop() {
        fetchTimer?.invalidate()
        cycleTimer?.invalidate()
        fetchTimer = nil
        cycleTimer = nil
    }

    private func refresh() {
        let request = URLRequest(url: rssSource, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 15)
        URLSession.shared.dataTask(with: request) { [weak self] data, _, _ in
            guard let self else { return }

            guard let data else {
                self.currentSegment = MarqueeSegment(prefixText: self.normalizedPrefix(), text: "RSS unavailable", actionURL: nil, slotWidth: self.slotWidth, allowsInnerScroll: true, innerScrollPause: self.innerScrollPause)
                self.onUpdate?()
                return
            }

            let parser = XMLParser(data: data)
            let state = RSSParserState()
            parser.delegate = state

            if parser.parse(), !state.headlines.isEmpty {
                self.headlines = state.headlines
                self.currentIndex = 0
                self.currentSegment = self.segment(for: self.headlines[self.currentIndex])
            } else {
                self.currentSegment = MarqueeSegment(prefixText: self.normalizedPrefix(), text: "No RSS headlines", actionURL: nil, slotWidth: self.slotWidth, allowsInnerScroll: true, innerScrollPause: self.innerScrollPause)
            }
            self.onUpdate?()
        }.resume()
    }

    private func advanceHeadline() {
        guard !headlines.isEmpty else {
            return
        }
        currentIndex = (currentIndex + 1) % headlines.count
        currentSegment = segment(for: headlines[currentIndex])
        onUpdate?()
    }

    private func segment(for headline: RSSHeadline) -> MarqueeSegment {
        let countSuffix = headlines.isEmpty ? "" : " \(currentIndex + 1)/\(headlines.count)"
        return MarqueeSegment(
            prefixText: normalizedPrefix(),
            text: headline.title + countSuffix,
            actionURL: headline.url,
            slotWidth: slotWidth,
            allowsInnerScroll: true,
            innerScrollPause: innerScrollPause
        )
    }

    private func normalizedPrefix() -> String? {
        let trimmed = prefix.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}

struct NewsHeadlinePlugin: MarqueeBlockPlugin {
    let type = "news_headline"

    func makeBlock(from definition: MarqueeBlockDefinition, context: MarqueePluginContext) throws -> MarqueeBlock {
        guard let source = definition.settings["rss_source"], let url = URL(string: source) else {
            throw MarqueePluginError.missingSetting(block: type, key: "rss_source")
        }
        let refreshInterval = context.refreshIntervalParser(definition.settings["refresh_interval"]) ?? 300
        let cycleInterval = context.refreshIntervalParser(definition.settings["cycle_interval"]) ?? 10
        let prefix = definition.settings["prefix"] ?? ""
        let slotWidth = CGFloat(Double(definition.settings["slot_width"] ?? "") ?? 360)
        let innerScrollPause = context.refreshIntervalParser(definition.settings["inner_scroll_pause"]) ?? 0.9
        return NewsHeadlineBlock(
            rssSource: url,
            refreshInterval: refreshInterval,
            cycleInterval: cycleInterval,
            prefix: prefix,
            slotWidth: slotWidth,
            innerScrollPause: innerScrollPause
        )
    }
}

private struct CoinbaseSpotResponse: Decodable {
    struct Data: Decodable {
        let amount: String
        let currency: String
    }

    let data: Data
}

final class CryptoTickerBlock: MarqueeBlock {
    private let symbol: String
    private let refreshInterval: TimeInterval
    private var timer: Timer?
    private var onUpdate: (() -> Void)?
    private(set) var currentSegment = MarqueeSegment(prefixText: nil, text: "Loading ticker", actionURL: nil, slotWidth: nil, allowsInnerScroll: false, innerScrollPause: nil)

    init(symbol: String, refreshInterval: TimeInterval) {
        self.symbol = symbol.uppercased()
        self.refreshInterval = refreshInterval
    }

    func start(onUpdate: @escaping () -> Void) {
        self.onUpdate = onUpdate
        refresh()
        timer = Timer.scheduledTimer(withTimeInterval: refreshInterval, repeats: true) { [weak self] _ in
            self?.refresh()
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    private func refresh() {
        guard let pair = currencyPair(from: symbol) else {
            currentSegment = MarqueeSegment(prefixText: nil, text: symbol, actionURL: tradingViewURL(for: symbol), slotWidth: nil, allowsInnerScroll: false, innerScrollPause: nil)
            onUpdate?()
            return
        }

        let endpoint = URL(string: "https://api.coinbase.com/v2/prices/\(pair.base)-\(pair.quote)/spot")!
        URLSession.shared.dataTask(with: endpoint) { [weak self] data, _, _ in
            guard let self else { return }
            let text: String

            if let data, let response = try? JSONDecoder().decode(CoinbaseSpotResponse.self, from: data) {
                text = "\(pair.base)\(pair.quote) \(response.data.amount) \(response.data.currency)"
            } else {
                text = "\(pair.base)\(pair.quote) unavailable"
            }

            self.currentSegment = MarqueeSegment(prefixText: nil, text: text, actionURL: self.tradingViewURL(for: self.symbol), slotWidth: nil, allowsInnerScroll: false, innerScrollPause: nil)
            self.onUpdate?()
        }.resume()
    }

    private func currencyPair(from symbol: String) -> (base: String, quote: String)? {
        let normalized = symbol.replacingOccurrences(of: "-", with: "").uppercased()
        let knownQuotes = ["USD", "USDT", "EUR", "GBP"]
        guard let quote = knownQuotes.first(where: { normalized.hasSuffix($0) }) else {
            return nil
        }
        let base = String(normalized.dropLast(quote.count))
        return base.isEmpty ? nil : (base, quote)
    }

    private func tradingViewURL(for symbol: String) -> URL? {
        URL(string: "https://www.tradingview.com/symbols/\(symbol.uppercased())/")
    }
}

struct CryptoTickerPlugin: MarqueeBlockPlugin {
    let type = "crypto_ticker"

    func makeBlock(from definition: MarqueeBlockDefinition, context: MarqueePluginContext) throws -> MarqueeBlock {
        guard let symbol = definition.settings["symbol"] ?? definition.settings["value"], !symbol.isEmpty else {
            throw MarqueePluginError.missingSetting(block: type, key: "symbol")
        }
        let refreshInterval = context.refreshIntervalParser(definition.settings["refresh_interval"]) ?? 60
        return CryptoTickerBlock(symbol: symbol, refreshInterval: refreshInterval)
    }
}
