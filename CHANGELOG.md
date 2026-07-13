# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- Registers with BoomForge and replaces the Patron tab's generic "has rewards" chest icon (in the existing Tip column) with the actual reward icon(s) for that order, resolved via `C_CurrencyInfo`/`C_Item` — no separate window, no new column, no need to open an order or hover to know what it pays out.
