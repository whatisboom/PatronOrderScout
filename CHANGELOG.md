# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [1.1.0] - 2026-07-16

### Added
- The Patron tab's Reagents column (retitled "Missing") now shows real icons for the reagents still needed to fulfill an order, in place of Blizzard's generic "All"/"Some"/"None" text. Missing reagents are resolved by diffing the recipe's full required-reagent list against what the patron already provided. Orders the patron covered completely now read "All Provided" explicitly instead of showing an empty cell. Hovering the column shows a tooltip broken into "Provided" and "Missing" sections, so both halves of the picture are visible at once.

### Fixed
- Reward icons in the Tip column would visibly shift position from row to row depending on how many digits the tip's gold/silver amount had, since they were anchored relative to the money display instead of a fixed point. Now anchored to a fixed position at the left edge of the column.

## [1.0.1] - 2026-07-14

### Fixed
- Reward icons that never appeared for some orders on first opening the Patron tab (most visibly Knowledge Points and Artisan Consortium payouts). Root cause: the underlying item data for some rewards wasn't cached client-side yet when the row first rendered, so its icon silently came back blank — the reward itself was always valid, just its icon couldn't be drawn yet. Now retried automatically once that data finishes loading (`GET_ITEM_INFO_RECEIVED`/`CURRENCY_DISPLAY_UPDATE`), no more needing to switch tabs away and back to see it.
- The addon's hook into Blizzard's UI could install a moment too late to catch the very first render of the Patron tab in a session, since the Blizzard addon it depends on loads on demand; now force-loaded proactively at login instead of waiting.

## [1.0.0] - 2026-07-13

### Added
- Registers with BoomForge and replaces the Patron tab's generic "has rewards" chest icon (in the existing Tip column) with the actual reward icon(s) for that order, resolved via `C_CurrencyInfo`/`C_Item` — no separate window, no new column, no need to open an order or hover to know what it pays out.
- Real item and currency icons, spaced for readability next to the tip amount.
- Hovering a reward icon shows its normal native tooltip (item or currency), anchored at the icon.
