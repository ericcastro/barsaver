# barsaver - a menubar screensaver for OLED displays

`barsaver` is a macOS menu bar overlay that helps reduce OLED burn-in by replacing a mostly static menu bar with dynamic scrolling content. It automatically fades away as the pointer approaches, so the normal menu bar stays instantly usable.

It behaves like a menu-bar screensaver rather than a menu-bar replacement: one overlay per selected display, aligned to the menu bar region, with click-through reveal near the top edge. The project now has a shared core with two frontends: the CLI utility and a menu bar app shell.

## What It Does

- Enumerates displays from the CLI
- Targets all displays, external displays, or specific display indices
- Creates one always-on-top overlay per selected display
- Covers exactly the menu bar region using `NSStatusBar.system.thickness`
- Draws an opaque black bar with a scrolling text marquee
- Applies subtle pixel drift over time to avoid a perfectly static image
- Fades out near the top edge of a display and restores itself when the pointer moves away
- Rebuilds overlays when displays are connected or disconnected
- Builds marquee content from configurable blocks and plugins

## Block Plugins

The content lane is built from block plugins, so `barsaver` is easy to extend without touching the overlay/windowing side.

Current built-in block types:

- `static_text`
  Displays a fixed string.
- `timestamp`
  Formats the current time using a `DateFormatter` format string.
- `news_headline`
  Fetches headlines from an RSS or Atom feed, refreshes the feed on `refresh_interval`, scrolls each item inside a fixed slot when needed, and only advances after that item's scroll has finished plus `cycle_interval`.
- `crypto_ticker`
  Fetches a spot price for symbols such as `BTCUSD` and `ETHUSD`.
- `stock_ticker`
  Fetches stock or ETF quotes for symbols such as `AAPL`, `MSFT`, or `SPY`.

Each block can also provide an action URL, so the marquee can stay interactive:

- `news_headline`
  Opens the article URL for the currently visible headline.
- `crypto_ticker`
  Opens a chart page for the symbol on TradingView.
- `stock_ticker`
  Opens a chart page for the symbol on TradingView.

To add a new content source, implement a `MarqueeBlockPlugin`, return a `MarqueeBlock`, and register it in `MarqueePluginRegistryValue`.

## Requirements

- macOS 13 or later
- Xcode command line tools or Xcode with Swift support

## Build

From the project root:

```bash
swift build
```

For local development you can also install it into your user toolchain:

```bash
swift build -c release
install -m 755 .build/release/barsaver /usr/local/bin/barsaver
```

## Usage

CLI:

List displays:

```bash
barsaver --list-displays
```

Run on all displays:

```bash
barsaver --displays all
```

Run only on non-main displays:

```bash
barsaver --displays external
```

Run on specific display indices:

```bash
barsaver --displays 1,2
```

Run with a custom content configuration:

```bash
barsaver --config ./barsaver.example.yaml --displays all
```

```bash
barsaver --list-displays --displays external
```

If `--config` is not provided, `barsaver` will look for `barsaver.yaml` and then `barsaver.yml` in the current directory before falling back to its built-in defaults.

Menu bar frontend:

```bash
barsaver-app
```

The menu bar app is intentionally minimal for now:

- launch at login toggle
- display target submenu
- open YAML config in your editor
- reload config
- open wiki / repo links
- quit

## Content Blocks

The marquee is built from a list of blocks. If no config file is provided, `barsaver` uses a small default set:

- `static_text: barsaver`
- `timestamp: HH:mm`
- `static_text: OLED-safe menubar`

The config format is YAML:

```yaml
hold_to_click_key: option
display_selection: all

blocks:
  - type: static_text
    value: barsaver
  - type: timestamp
    format: HH:mm
  - type: static_text
    value: OLED-safe menubar
  - type: news_headline
    prefix: BBC
    rss_source: https://feeds.bbci.co.uk/news/world/rss.xml
    refresh_interval: 5m
    cycle_interval: 10s
    slot_width: 360
    inner_scroll_pause: 0.9s
  - type: crypto_ticker
    symbol: BTCUSD
    refresh_interval: 1m
  - type: stock_ticker
    symbol: SPY
    refresh_interval: 1m
  - type: crypto_ticker
    symbol: ETHUSD
    refresh_interval: 1m
```

Each item in `blocks` creates one scrolling block. The `type` field selects the plugin, and the remaining keys become that block's settings.

Top-level settings currently supported:

- `hold_to_click_key`
  Holds the overlay visible so links can be clicked without auto-hide kicking in. Supported values: `option`, `command`, `control`, `shift`, `capslock`, `fn`.
- `display_selection`
  Default display target for the shared runtime. Supported values: `all`, `external`, or a comma-separated index list such as `1,2`.

Supported refresh interval suffixes:

- `30s`
- `1m`
- `2h`

Crypto prices currently use Coinbase's public spot-price endpoint:

- [Coinbase Data API Prices](https://docs.cdp.coinbase.com/coinbase-app/track-apis/prices)

Stock and ETF quotes currently use Alpha Vantage's `GLOBAL_QUOTE` endpoint:

- [Alpha Vantage Documentation](https://www.alphavantage.co/documentation/)

For `stock_ticker`, provide an Alpha Vantage API key either:

- in the block as `api_key: "..."`, or
- via the `ALPHA_VANTAGE_API_KEY` environment variable

Because the overlay normally auto-hides as the pointer approaches the menu bar, hold the configured modifier key to keep the bar visible long enough to click it. While that modifier is held and the pointer is over the bar, the marquee pauses to make links easier to target.

Clickable `news_headline` text is yellow by default and turns cyan while hovered. Pinned prefixes stay white. Other actionable blocks remain white and switch cursor on hover.

For fixed-width nested scrolling blocks such as `news_headline`, these settings are also available:

- `slot_width`
  Reserves a fixed-width lane so the rest of the marquee does not shift when the headline changes.
- `inner_scroll_pause`
  Controls how long the text waits at each end of the inner scroll before moving again.
- `cycle_interval`
  Controls how long a fetched headline stays on screen after its inner scroll has finished.

RSS headlines also include an item count suffix such as `1/8` so it is easier to tell how many fetched items are being rotated.

## Testing

```bash
swift build
swift test
barsaver --list-displays
barsaver --displays all
```

Expected behavior:

- the selected displays get a black overlay aligned to the menu bar region
- the marquee scrolls continuously and updates as block sources refresh
- approaching the top edge fades the overlay and returns normal menu bar interaction
- moving away restores the overlay
- connecting or disconnecting a display reapplies overlays automatically

## Permissions and Notes

Depending on macOS settings, global mouse tracking may be affected by system privacy controls. Relevant panels:

- `System Settings > Privacy & Security > Accessibility`
- `System Settings > Privacy & Security > Input Monitoring`

The utility does not patch, replace, or otherwise modify the macOS menu bar. It only places standard AppKit windows above it.

Some content plugins depend on external network sources. If a feed or ticker endpoint is unavailable, the corresponding block will fall back to a short status string instead of stopping the overlay.

## Implementation Notes

The code is organized into a few focused pieces:

- `BarsaverCore` contains the shared overlay engine, block/plugin system, config loading, display selection, and runtime coordination
- `barsaver` is the CLI frontend
- `barsaver-app` is the menu bar frontend shell
- `DisplayManager` provides deterministic display ordering and selection
- `OverlayController` owns one overlay window per display
- `MouseTracker` watches pointer position and controls reveal/hide behavior
- `ContentView` renders the marquee and background using AppKit and Core Animation
- `MarqueeConfiguration`, `MarqueePlugin`, and `MarqueeContentController` handle block-based scrolling content

The menu bar app currently runs as a SwiftPM-built AppKit executable. For production-quality no-Dock behavior and login-item packaging, the next step is to wrap that frontend in a proper Xcode app target and keep `BarsaverCore` unchanged underneath.
