# Patron Order Scout

See what a patron (NPC) crafting order rewards — Knowledge Points, Augment Runes, Artisan's Mettle, etc. — without opening each order individually.

## Requires

[BoomForge](https://github.com/whatisboom/BoomForge) — install it alongside this addon. Patron Order Scout registers with BoomForge for its shared Ace3 libraries and logging; it has no vendored `Libs/` of its own.

## What it does

On the Professions window's Patron tab, Blizzard's own order table already shows a small "has rewards" chest icon in the Tip column when an order grants a reward, with reward details only visible on hover. Patron Order Scout replaces that chest icon with the actual reward icon(s) — resolved via `C_CurrencyInfo`/`C_Item` — so you can see at a glance what an order pays out (Knowledge Points, an Augment Rune, Artisan's Mettle, etc.) without hovering or opening the order. Hovering an icon still shows its normal native tooltip.

This is done entirely in place, inside Blizzard's existing Patron tab UI — no separate window, no minimap icon, no extra addon surface.

## Tests

Pure-Lua reward-resolution logic (`Rewards.lua`'s `Rewards.resolve`) is covered by `tests/run.lua`:

```
lua tests/run.lua
```

The rest of `Rewards.lua` (the Tip-column hook, icon frames, tooltips) and `Core.lua` call live WoW API and Blizzard UI internals that don't exist outside the client, so they're verified manually in-game instead.

## License

MIT — see `LICENSE`.
