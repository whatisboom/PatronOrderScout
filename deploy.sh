#!/usr/bin/env bash
# Deploy the working tree into the live WoW AddOns folder for in-game testing.
#
# No Libs/ to seed or preserve here -- PatronOrderScout has no vendored
# libraries of its own; everything comes from the required BoomForge dependency
# (deploy that separately). Run, then /reload in game.
set -euo pipefail

SRC="$HOME/projects/PatronOrderScout/"
DEST="/Applications/World of Warcraft/_retail_/Interface/AddOns/PatronOrderScout/"

rsync -a --delete \
  --exclude='.git/' \
  --exclude='.gitignore' \
  --exclude='.pkgmeta' \
  --exclude='.DS_Store' \
  --exclude='tests/' \
  --exclude='CLAUDE.md' \
  --exclude='deploy.sh' \
  "$SRC" "$DEST"

echo "Deployed to live AddOns folder. /reload in game."
