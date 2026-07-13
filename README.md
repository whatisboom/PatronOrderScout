# Patron Order Scout

See what a patron (NPC) crafting order rewards — Knowledge Points, Augment Runes, Artisan's Mettle, etc. — without opening each order individually.

## Requires

[BoomForge](https://github.com/whatisboom/BoomForge) — install it alongside this addon. Patron Order Scout registers with BoomForge for its shared Ace3 libraries and logging; it has no vendored `Libs/` of its own.

## What it does

Requests your available patron crafting orders (`C_CraftingOrders`) and resolves each order's reward payload (currency rewards like Knowledge Points, item rewards like Augment Runes) via `C_CurrencyInfo`/`C_Item` — no need to click into an order to see what it pays out. Results show up as a LibDataBroker data source (works with any LDB display addon), with a tooltip listing each visible order and its rewards.

Filtering by reward category (`db.profile.filters`, e.g. only show orders with Knowledge Points) is data-driven off the resolved reward name — see `Format.lua`.

## Tests

Pure-Lua logic (`Format.lua`) is covered by `tests/run.lua`:

```
lua tests/run.lua
```

`Scanner.lua`/`Core.lua`/`Broker.lua` call live WoW API and are verified manually in-game instead.

## License

MIT — see `LICENSE`.
