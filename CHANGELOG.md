# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- Initial scaffold: registers with BoomForge, scans available patron crafting orders via `C_CraftingOrders`, and surfaces their rewards (Knowledge Points, Augment Runes, Artisan's Mettle, etc.) through a LibDataBroker tooltip without needing to open each order.
