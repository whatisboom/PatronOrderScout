local ADDON, ns = ...
local Scanner = {}
ns.Scanner = Scanner

-- orderID -> resolved order table: { orderID, itemLink, tipAmount, rewards = {...} }
Scanner.orders = {}

-- Resolve one raw CraftingOrderRewardInfo ({ itemLink?, currencyType?, count })
-- into Format.lua's { kind, name, icon, count } shape. Resolved live via
-- C_CurrencyInfo/C_Item rather than a hardcoded ID table (see Format.lua).
local function resolveReward(raw)
  if raw.currencyType then
    local info = C_CurrencyInfo.GetCurrencyInfo(raw.currencyType)
    return {
      kind = "currency",
      name = (info and info.name) or ("Currency " .. raw.currencyType),
      icon = info and info.iconFileID,
      count = raw.count,
    }
  end
  local name, _, _, _, icon = C_Item.GetItemInfo(raw.itemLink)
  return {
    kind = "item",
    name = name or raw.itemLink or "Unknown Item",
    icon = icon,
    count = raw.count,
  }
end

local function resolveRewards(rawRewards)
  local rewards = {}
  for _, raw in ipairs(rawRewards or {}) do
    rewards[#rewards + 1] = resolveReward(raw)
  end
  return rewards
end

-- Kicks off an async fetch of the crafter's available orders (patron/NPC orders
-- only). GetCrafterOrders() is populated once the CraftingOrderRequestCallback
-- fires; npcOrderRewards on those orders may still arrive later via the
-- CRAFTINGORDERS_UPDATE_REWARDS event (see Core.lua:OnRewardsUpdated).
function Scanner:RequestOrders()
  C_CraftingOrders.RequestCrafterOrders({
    orderType = Enum.CraftingOrderType.Npc,
    searchFavorites = false,
    initialNonPublicSearch = false,
    primarySort = { sortType = Enum.CraftingOrderSortType.TimeRemaining, reversed = false },
    secondarySort = { sortType = Enum.CraftingOrderSortType.TimeRemaining, reversed = false },
    forCrafter = true,
    offset = 0,
    callback = function()
      Scanner:Scan()
      ns.Broker:Update()
    end,
  })
end

-- Rebuilds Scanner.orders from the client's current crafter-order list.
function Scanner:Scan()
  local orders = {}
  for _, order in ipairs(C_CraftingOrders.GetCrafterOrders() or {}) do
    orders[order.orderID] = {
      orderID = order.orderID,
      itemLink = order.outputItemHyperlink,
      tipAmount = order.tipAmount,
      rewards = resolveRewards(order.npcOrderRewards),
    }
  end
  self.orders = orders
end

-- Applies a late-arriving CRAFTINGORDERS_UPDATE_REWARDS payload to an
-- already-scanned order.
function Scanner:SetRewards(orderID, npcOrderRewards)
  local order = self.orders[orderID]
  if not order then return end
  order.rewards = resolveRewards(npcOrderRewards)
end

-- Orders matching the active filter set, sorted by orderID for stable display
-- order. orderID is a BigUInteger, so it's compared as a string rather than
-- assuming numeric `<` is supported on that type.
function Scanner:VisibleOrders(filters)
  local out = {}
  for _, order in pairs(self.orders) do
    if ns.Format.matchesFilter(order, filters) then
      out[#out + 1] = order
    end
  end
  table.sort(out, function(a, b) return tostring(a.orderID) < tostring(b.orderID) end)
  return out
end
