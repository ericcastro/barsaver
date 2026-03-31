# barsaver

`barsaver` is a macOS overlay that covers the menu bar when it is idle to help prevent OLED burn-in on external or built-in displays. It shows dynamic, non-static content and automatically fades away as the pointer approaches, so the normal menu bar stays instantly usable.

The app is launched from the command line, runs as a background AppKit process, and keeps one overlay window per selected display. When the cursor approaches the top edge of a display, the overlay fades away and stops intercepting mouse input so the menu bar can be used normally. When the cursor leaves, the overlay returns.

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

## Requirements

- macOS 13 or later
- Xcode command line tools or Xcode with Swift support

## Build

From the project root:

```bash
swift build
```

The debug binary will be created at:

```bash
./.build/debug/barsaver
```

## Usage

List displays:

```bash
./.build/debug/barsaver --list-displays
```

Run on all displays:

```bash
./.build/debug/barsaver --displays all
```

Run only on non-main displays:

```bash
./.build/debug/barsaver --displays external
```

Run on specific display indices:

```bash
./.build/debug/barsaver --displays 1,2
```

Run with a custom content configuration:

```bash
./.build/debug/barsaver --config ~/barsaver.conf --displays all
```

Or use the example config in the repo:

```bash
./.build/debug/barsaver --config ./barsaver.example.conf --displays all
```

You can also combine display listing with launch selection:

```bash
./.build/debug/barsaver --list-displays --displays external
```

## Content Blocks

The marquee is built from a list of blocks. If no config file is provided, `barsaver` uses a small default set:

- `static_text: barsaver`
- `timestamp: HH:mm`
- `static_text: OLED-safe menubar`

The config format is a small indentation-based format inspired by YAML:

```txt
hold_to_click_key: "option"

block_static_text: "barsaver"
block_timestamp:
  format: "HH:mm"
block_static_text: "OLED-safe menubar"
block_news_headline:
  prefix: "BBC"
  rss_source: "https://feeds.bbci.co.uk/news/world/rss.xml"
  refresh_interval: "5m"
  cycle_interval: "10s"
  slot_width: "360"
  inner_scroll_pause: "0.9s"
block_crypto_ticker:
  symbol: "BTCUSD"
  refresh_interval: "1m"
block_stock_ticker:
  symbol: "SPY"
  refresh_interval: "1m"
block_crypto_ticker:
  symbol: "ETHUSD"
  refresh_interval: "1m"
```

Each top-level `block_*` entry creates one scrolling block. Inline values are stored as `value`, while indented keys become plugin settings.

Top-level settings currently supported:

- `hold_to_click_key`
  Holds the overlay visible so links can be clicked without auto-hide kicking in. Supported values: `option`, `command`, `control`, `shift`, `capslock`, `fn`.

Supported refresh interval suffixes:

- `30s`
- `1m`
- `2h`

## Built-In Plugins

Current built-in block types:

- `block_static_text`
  Displays a fixed string.
- `block_timestamp`
  Formats the current time using a `DateFormatter` format string.
- `block_news_headline`
  Fetches headlines from an RSS or Atom feed, refreshes the feed on one interval, and rotates through the fetched items on a separate interval.
- `block_crypto_ticker`
  Fetches a spot price for symbols such as `BTCUSD` and `ETHUSD`.
- `block_stock_ticker`
  Fetches stock or ETF quotes for symbols such as `AAPL`, `MSFT`, or `SPY`.

Crypto prices currently use Coinbase's public spot-price endpoint:

- [Coinbase Data API Prices](https://docs.cdp.coinbase.com/coinbase-app/track-apis/prices)

Stock and ETF quotes currently use Alpha Vantage's `GLOBAL_QUOTE` endpoint:

- [Alpha Vantage Documentation](https://www.alphavantage.co/documentation/)

For `block_stock_ticker`, provide an Alpha Vantage API key either:

- in the block as `api_key: "..."`, or
- via the `ALPHA_VANTAGE_API_KEY` environment variable

## Clickable Content

Each block can provide an action URL. The marquee keeps those links attached to the visible text so segments can be clicked.

- `block_news_headline`
  Opens the article URL for the currently visible headline.
- `block_crypto_ticker`
  Opens a chart page for the symbol on TradingView.
- `block_stock_ticker`
  Opens a chart page for the symbol on TradingView.
- `block_static_text` and `block_timestamp`
  Do not currently attach actions.

Because the overlay normally auto-hides as the pointer approaches the menu bar, hold the configured modifier key to keep the bar visible long enough to click it.
Clickable RSS headline text is yellow by default and turns cyan while hovered. Pinned prefixes stay white.

For fixed-width nested scrolling blocks such as `block_news_headline`, these settings are also available:

- `slot_width`
  Reserves a fixed-width lane so the rest of the marquee does not shift when the headline changes.
- `inner_scroll_pause`
  Controls how long the text waits at each end of the inner scroll before moving again.

RSS headlines also include an item count suffix such as `1/8` so it is easier to tell how many fetched items are being rotated.

## Extending Plugins

The content system is intentionally small:

- `MarqueeConfiguration` parses the config file into block definitions
- `MarqueePluginRegistryValue` resolves block types to plugins
- Each plugin builds a `MarqueeBlock`
- `MarqueeContentController` joins block output into the final marquee string

To add a new plugin:

1. Create a type that conforms to `MarqueeBlockPlugin`.
2. Create a block object that conforms to `MarqueeBlock`.
3. Register the plugin in `MarqueePluginRegistryValue`.

That keeps new content sources isolated from the overlay and windowing code.

## Testing

A good first pass is:

```bash
swift build
./.build/debug/barsaver --list-displays
./.build/debug/barsaver --displays all
```

Once the app is running, verify the following:

- The process stays attached to the terminal and continues running until interrupted
- A black overlay appears over the menu bar region of the selected displays
- The marquee text scrolls continuously
- The marquee content updates when block sources refresh
- The overlay shifts subtly over time instead of remaining perfectly static
- Moving the cursor near the top edge of a covered display fades the overlay out
- While faded out, the menu bar is clickable and behaves normally
- Moving the cursor away restores the overlay
- Connecting or disconnecting a display causes overlays to update automatically

Stop the process with:

```bash
Ctrl-C
```

## Permissions and Notes

Depending on macOS settings, global mouse tracking may be affected by system privacy controls. If the fade behavior does not respond as expected, check:

- `System Settings > Privacy & Security > Accessibility`
- `System Settings > Privacy & Security > Input Monitoring`

The utility does not patch, replace, or otherwise modify the macOS menu bar. It only places standard AppKit windows above it.

Some content plugins depend on external network sources. If a feed or ticker endpoint is unavailable, the corresponding block will fall back to a short status string instead of stopping the overlay.

## Implementation Notes

The code is organized into a few focused pieces:

- `CLIParser` handles command-line arguments
- `DisplayManager` provides deterministic display ordering and selection
- `OverlayController` owns one overlay window per display
- `MouseTracker` watches pointer position and controls reveal/hide behavior
- `ContentView` renders the marquee and background using AppKit and Core Animation
- `MarqueeConfiguration`, `MarqueePlugin`, and `MarqueeContentController` handle block-based scrolling content

This is an AppKit-first implementation intended to stay lightweight and easy to adjust.
