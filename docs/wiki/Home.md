# barsaver Wiki

`barsaver` is built around block plugins. The overlay engine is generic; the YAML config decides what content appears in the marquee and how it behaves.

Start here:

- [Configuration](./Configuration.md)
- [Block Types](./Block-Types.md)
- [Examples](./Examples.md)

Current built-in blocks:

- `static_text`
- `timestamp`
- `news_headline`
- `crypto_ticker`
- `stock_ticker`

Core ideas:

- each block is independent
- blocks publish normalized marquee segments
- the renderer does not care where a segment came from
- new block types can be added without changing the overlay system
