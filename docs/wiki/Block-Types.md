# Block Types

## `static_text`

```yaml
- type: static_text
  value: barsaver
```

Keys:

- `value`

## `timestamp`

```yaml
- type: timestamp
  format: HH:mm
```

Keys:

- `format`
  Uses `DateFormatter` formatting

## `news_headline`

```yaml
- type: news_headline
  prefix: BBC
  rss_source: https://feeds.bbci.co.uk/news/world/rss.xml
  refresh_interval: 5m
  cycle_interval: 10s
  slot_width: 360
  inner_scroll_pause: 0.9s
```

Keys:

- `prefix`
  Optional pinned label shown before the scrolling headline
- `rss_source`
  RSS or Atom feed URL
- `refresh_interval`
  How often the feed is fetched again
- `cycle_interval`
  How long the current headline stays on screen after its inner scroll completes
- `slot_width`
  Fixed width reserved for the headline slot
- `inner_scroll_pause`
  Pause duration at the start/end of the inner scroll

Notes:

- each `news_headline` block is independent
- each block manages its own fetch, cycle timing, and animation state
- clickable headline text opens the article URL

## `crypto_ticker`

```yaml
- type: crypto_ticker
  symbol: BTCUSD
  refresh_interval: 1m
```

Keys:

- `symbol`
- `refresh_interval`

Notes:

- uses Coinbase spot pricing
- opens the symbol on TradingView

## `stock_ticker`

```yaml
- type: stock_ticker
  symbol: SPY
  refresh_interval: 1m
  api_key: YOUR_ALPHA_VANTAGE_API_KEY
```

Keys:

- `symbol`
- `refresh_interval`
- `api_key`

Notes:

- uses Alpha Vantage `GLOBAL_QUOTE`
- `api_key` can be omitted if `ALPHA_VANTAGE_API_KEY` is set in the environment
- opens the symbol on TradingView
