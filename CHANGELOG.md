# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [1.0.0] - 2026-07-13

### Added
- Registers with BoomForge and replaces the Patron tab's generic "has rewards" chest icon (in the existing Tip column) with the actual reward icon(s) for that order, resolved via `C_CurrencyInfo`/`C_Item` — no separate window, no new column, no need to open an order or hover to know what it pays out.
- Real item and currency icons, spaced for readability next to the tip amount.
- Hovering a reward icon shows its normal native tooltip (item or currency), anchored at the icon.
