local ADDON, ns = ...
local Format = {}
ns.Format = Format

-- Reward category is derived from the live-resolved display name (via
-- C_CurrencyInfo/C_Item in Scanner.lua), not a hardcoded currency/item ID table --
-- names are stable season-to-season even when the underlying IDs aren't.
local CATEGORY_PATTERNS = {
  { pattern = "Knowledge", category = "knowledge" },
  { pattern = "Augment Rune", category = "augment_rune" },
  { pattern = "Artisan's Mettle", category = "mettle" },
  { pattern = "Artisan's Acuity", category = "mettle" },
}

function Format.categorize(reward)
  for _, entry in ipairs(CATEGORY_PATTERNS) do
    if reward.name:find(entry.pattern, 1, true) then return entry.category end
  end
  return "other"
end

-- The set of reward categories present anywhere in an order's rewards, e.g.
-- { knowledge = true, augment_rune = true }.
function Format.categorizeOrder(order)
  local cats = {}
  for _, reward in ipairs(order.rewards) do
    cats[Format.categorize(reward)] = true
  end
  return cats
end

-- Whether an order should be shown under the given active filter set (a set of
-- category -> true, e.g. { knowledge = true }). An empty filter set matches
-- everything (no filter selected = show all); otherwise the order matches if it
-- has a reward in *any* selected category.
function Format.matchesFilter(order, filters)
  if next(filters) == nil then return true end
  local cats = Format.categorizeOrder(order)
  for category in pairs(filters) do
    if cats[category] then return true end
  end
  return false
end

function Format.rewardLine(reward)
  return ("%dx %s"):format(reward.count, reward.name)
end

function Format.orderRewardsText(order)
  local lines = {}
  for _, reward in ipairs(order.rewards) do
    lines[#lines + 1] = Format.rewardLine(reward)
  end
  return table.concat(lines, ", ")
end
