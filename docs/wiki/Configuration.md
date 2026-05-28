# Configuration

The menu bar app reads its config from:

```text
~/Library/Application Support/barsaver/barsaver.yaml
```

The CLI reads:

1. the path passed with `--config`
2. `./barsaver.yaml`
3. `./barsaver.yml`
4. built-in defaults

## Top-Level Settings

```yaml
hold_to_click_key: escape
display_selection: all
```

Supported top-level keys:

- `hold_to_click_key`
  Supported values: `escape`, `option`, `command`, `control`, `shift`, `capslock`, `fn`
- `display_selection`
  Supported values: `all`, `external`, or a comma-separated index list like `1,2`

`hold_to_click_key` defaults to `escape`. While that key is held, the overlay stays visible instead of auto-hiding near the menu bar.

## Blocks

Blocks live under `blocks:` and are evaluated in order.

```yaml
blocks:
  - type: static_text
    value: barsaver
  - type: timestamp
    format: HH:mm
```

Every block must have:

- `type`

All other keys are block-specific.
