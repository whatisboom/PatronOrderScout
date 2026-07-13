-- Standalone test runner. Run: lua tests/run.lua
-- Tests PatronOrderScout's pure-Lua modules (Format.lua) outside the WoW client,
-- the same way BoomForge/VaultTracker's tests/run.lua test their pure-logic modules.
-- Scanner.lua/Core.lua/Broker.lua call live WoW API (C_CraftingOrders, AceAddon,
-- LibDataBroker) and are verified manually in-game instead.
local passed, failed = 0, 0

local function eq(actual, expected, msg)
  if actual == expected then passed = passed + 1
  else failed = failed + 1
    print(("FAIL: %s\n  expected %s, got %s"):format(msg, tostring(expected), tostring(actual)))
  end
end

local function ok(cond, msg)
  if cond then passed = passed + 1
  else failed = failed + 1
    print(("FAIL: %s"):format(msg))
  end
end

-- Load a WoW addon file the same way WoW does: chunk(addonName, ns).
local function loadModule(path, ns)
  local chunk = assert(loadfile(path))
  chunk("PatronOrderScout", ns)
end

local ns = {}
loadModule("Format.lua", ns)
local Format = ns.Format

-- ---- Format.categorize ----
eq(Format.categorize({ kind = "currency", name = "Knowledge Points" }), "knowledge",
  "a currency reward named 'Knowledge Points' categorizes as knowledge")
eq(Format.categorize({ kind = "item", name = "Crystallized Augment Rune" }), "augment_rune",
  "an item reward whose name contains 'Augment Rune' categorizes as augment_rune")
eq(Format.categorize({ kind = "currency", name = "Artisan's Mettle" }), "mettle",
  "a currency reward named \"Artisan's Mettle\" categorizes as mettle")
eq(Format.categorize({ kind = "item", name = "Some Random Reagent" }), "other",
  "an unrecognized reward name categorizes as other")

-- ---- Format.categorizeOrder ----
do
  local order = { rewards = {
    { kind = "currency", name = "Knowledge Points", count = 5 },
    { kind = "item", name = "Crystallized Augment Rune", count = 1 },
  } }
  local cats = Format.categorizeOrder(order)
  ok(cats.knowledge, "categorizeOrder includes knowledge when a reward is Knowledge Points")
  ok(cats.augment_rune, "categorizeOrder includes augment_rune when a reward is an Augment Rune")
  ok(not cats.mettle, "categorizeOrder excludes mettle when no reward matches it")
end

-- ---- Format.matchesFilter ----
do
  local order = { rewards = {
    { kind = "currency", name = "Knowledge Points", count = 5 },
  } }
  ok(Format.matchesFilter(order, {}), "an empty filter set matches every order")
  ok(Format.matchesFilter(order, { knowledge = true }),
    "a filter set matches an order that has a reward in that category")
  ok(not Format.matchesFilter(order, { mettle = true }),
    "a filter set does not match an order lacking any selected category")
  ok(Format.matchesFilter(order, { mettle = true, knowledge = true }),
    "a filter set matches when the order has at least one of several selected categories")
end

-- ---- Format.rewardLine / Format.orderRewardsText ----
eq(Format.rewardLine({ name = "Knowledge Points", count = 5 }), "5x Knowledge Points",
  "rewardLine renders count and name")

do
  local order = { rewards = {
    { name = "Knowledge Points", count = 5 },
    { name = "Crystallized Augment Rune", count = 1 },
  } }
  eq(Format.orderRewardsText(order), "5x Knowledge Points, 1x Crystallized Augment Rune",
    "orderRewardsText joins each reward's line with a comma")
end

-- ---- Format.toggleFilter ----
do
  local filters = {}
  local nowActive = Format.toggleFilter(filters, "knowledge")
  ok(nowActive, "toggleFilter returns true when it turns a category on")
  ok(filters.knowledge, "toggleFilter adds the category to the filter set")

  nowActive = Format.toggleFilter(filters, "knowledge")
  ok(not nowActive, "toggleFilter returns false when it turns a category back off")
  ok(not filters.knowledge, "toggleFilter removes the category from the filter set")
end

-- ---- Format.filterSummary ----
eq(Format.filterSummary({}), "none (showing all)",
  "filterSummary reports 'showing all' when no filters are active")
eq(Format.filterSummary({ knowledge = true }), "knowledge",
  "filterSummary lists a single active category")
eq(Format.filterSummary({ knowledge = true, mettle = true }), "knowledge, mettle",
  "filterSummary lists multiple active categories, sorted for stable output")

print(("\n%d passed, %d failed"):format(passed, failed))
if failed > 0 then os.exit(1) end
