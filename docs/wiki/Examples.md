# Examples

## Minimal

```yaml
hold_to_click_key: escape
display_selection: all

blocks:
  - type: static_text
    value: barsaver
  - type: timestamp
    format: HH:mm
```

## News Lane

```yaml
hold_to_click_key: escape
display_selection: external

blocks:
  - type: static_text
    value: OLED-safe menubar
  - type: news_headline
    prefix: BBC
    rss_source: https://feeds.bbci.co.uk/news/world/rss.xml
    refresh_interval: 5m
    cycle_interval: 10s
    slot_width: 360
    inner_scroll_pause: 0.9s
  - type: news_headline
    prefix: "🇦🇷"
    rss_source: https://www.infobae.com/arc/outboundfeeds/rss/
    refresh_interval: 5m
  - type: news_headline
    prefix: "🇫🇷"
    rss_source: https://www.franceinfo.fr/titres.rss
    refresh_interval: 5m
```

## Mixed Market Bar

```yaml
hold_to_click_key: escape
display_selection: 1

blocks:
  - type: timestamp
    format: HH:mm
  - type: crypto_ticker
    symbol: BTCUSD
    refresh_interval: 1m
  - type: crypto_ticker
    symbol: ETHUSD
    refresh_interval: 1m
  - type: stock_ticker
    symbol: SPY
    refresh_interval: 1m
  - type: stock_ticker
    symbol: AAPL
    refresh_interval: 1m
```
