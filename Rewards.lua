local ADDON, ns = ...
local Rewards = {}
ns.Rewards = Rewards

-- Resolves one raw CraftingOrderRewardInfo ({ itemLink?, currencyType?, count })
-- into a display-ready shape via the shared Resolve module. `icon` can come
-- back nil if the underlying currency/item data isn't cached client-side yet
-- (e.g. a currency the player hasn't "discovered" yet) -- callers must handle
-- that, not assume a resolved reward always has a usable icon.
function Rewards.resolve(raw)
  if raw.currencyType then
    return ns.Resolve.currency(raw.currencyType)
  end
  return ns.Resolve.item(raw.itemLink)
end

local MAX_REWARD_ICONS = 2 -- NPC_CRAFTING_ORDER_NUM_SUPPORTED_REWARDS

-- orderID (as a string -- BigUInteger values aren't safe to use as table keys
-- directly) -> { cell = <frame>, npcOrderRewards = <list, or nil> } for any
-- row still waiting on something: `npcOrderRewards == nil` means we're still
-- waiting on the reward *list itself* (RequestPendingRewards's job, a fresh
-- C_CraftingOrders.RequestCrafterOrders() call); a non-nil `npcOrderRewards`
-- with the entry still present means the reward list arrived but at least one
-- reward's icon didn't resolve yet (RetryIconResolution's job, no new request
-- needed -- just re-run Rewards.resolve once the underlying data is cached).
local activeCells = {}

local function OnIconEnter(iconFrame)
  GameTooltip:SetOwner(iconFrame, "ANCHOR_TOP")
  local raw = iconFrame.reward
  if raw.currencyType then
    GameTooltip:SetCurrencyByID(raw.currencyType)
  else
    GameTooltip:SetHyperlink(raw.itemLink)
  end
  GameTooltip:Show()
end

local function OnIconLeave()
  GameTooltip:Hide()
end

-- Lazily creates (once per pooled cell frame, since TableBuilder cells are
-- reused across rows as the list scrolls) the icon frames we show in place of
-- Blizzard's chest icon, anchored exactly where that chest icon sits.
local function GetOrCreateIcons(cell)
  return ns.IconRow.GetOrCreate(cell, "patronOrderScoutIcons", MAX_REWARD_ICONS,
    cell.TipMoneyDisplayFrame, "LEFT", -10, OnIconEnter, OnIconLeave)
end

-- Shows up to MAX_REWARD_ICONS real reward icons on `cell`, replacing
-- Blizzard's generic chest icon. Returns `complete` -- false if any reward's
-- icon came back nil (data not cached client-side yet), so the caller knows
-- to keep this cell pending rather than treat it as done.
local function ShowRewardIcons(cell, npcOrderRewards)
  local icons = GetOrCreateIcons(cell)
  cell.RewardIcon:Hide()

  local complete = true
  for i, iconFrame in ipairs(icons) do
    local raw = npcOrderRewards[i]
    if raw then
      local resolved = Rewards.resolve(raw)
      iconFrame.icon:SetTexture(resolved.icon)
      iconFrame.reward = raw
      iconFrame:Show()
      if not resolved.icon then
        complete = false
      end
    else
      iconFrame:Hide()
    end
  end
  return complete
end

-- Hides any reward icons already on `cell` (leaving Blizzard's own RewardIcon
-- shown/hidden exactly as its own Populate already decided). Used when a
-- pooled cell is repopulated for an order with no rewards, so icons/tooltip
-- data left over from whatever order previously occupied this cell don't
-- linger on the new row.
local function HideRewardIcons(cell)
  ns.IconRow.HideAll(cell, "patronOrderScoutIcons")
end

-- Refreshes a cell already displaying `orderID`, if any, with newly-arrived
-- reward data (see CRAFTINGORDERS_UPDATE_REWARDS handling in Core.lua). Only
-- applies the update if the cell we have on record is still showing this
-- orderID -- pooled cells get reused for other orders as the list scrolls, so
-- a late event for an order whose cell has since moved on must be ignored.
function Rewards.OnRewardsUpdated(orderIDString, npcOrderRewards)
  local pending = activeCells[orderIDString]
  local cell = pending and pending.cell
  if cell and cell.patronOrderScoutOrderID == orderIDString and npcOrderRewards and #npcOrderRewards > 0 then
    if ShowRewardIcons(cell, npcOrderRewards) then
      activeCells[orderIDString] = nil
    else
      activeCells[orderIDString] = { cell = cell, npcOrderRewards = npcOrderRewards }
    end
  end
end

local pollTicker = nil

-- Backstop for rows whose reward *list* never arrives via
-- CRAFTINGORDERS_UPDATE_REWARDS (that event isn't reliably fired for orders
-- sitting in a background list rather than the one currently open).
-- C_CraftingOrders.GetCrafterOrders() only reflects whatever the last actual
-- request returned -- it's not a live cache -- so a passive re-read never sees
-- newly-resolved reward data. An explicit RequestCrafterOrders() call is what
-- actually asks the server for a fresh snapshot (this is what switching tabs
-- away and back was observed to trigger). Unlike the reactive polling that
-- originally broke the built-in Patron tab count (see Core.lua/git history),
-- this is time-driven, not triggered by CRAFTINGORDERS_UPDATE_ORDER_COUNT, so
-- it can't chain into a request storm -- it fires at most once per interval
-- while any row is still waiting, and stops itself once nothing is.
--
-- Only entries still missing their reward *list* (npcOrderRewards == nil) need
-- this -- entries only waiting on icon resolution are RetryIconResolution's job.
local function RequestPendingRewards()
  local anyMissingList = false
  for _, pending in pairs(activeCells) do
    if not pending.npcOrderRewards then anyMissingList = true; break end
  end
  if not anyMissingList then
    if pollTicker then
      pollTicker:Cancel()
      pollTicker = nil
    end
    return
  end

  C_CraftingOrders.RequestCrafterOrders({
    orderType = Enum.CraftingOrderType.Npc,
    searchFavorites = false,
    initialNonPublicSearch = false,
    primarySort = { sortType = Enum.CraftingOrderSortType.TimeRemaining, reversed = false },
    secondarySort = { sortType = Enum.CraftingOrderSortType.TimeRemaining, reversed = false },
    forCrafter = true,
    offset = 0,
    callback = function()
      local rewardsByOrderID = {}
      for _, order in ipairs(C_CraftingOrders.GetCrafterOrders() or {}) do
        if order.npcOrderRewards and #order.npcOrderRewards > 0 then
          rewardsByOrderID[tostring(order.orderID)] = order.npcOrderRewards
        end
      end

      for orderIDString, pending in pairs(activeCells) do
        local npcOrderRewards = rewardsByOrderID[orderIDString]
        if npcOrderRewards and pending.cell.patronOrderScoutOrderID == orderIDString then
          if ShowRewardIcons(pending.cell, npcOrderRewards) then
            activeCells[orderIDString] = nil
          else
            activeCells[orderIDString] = { cell = pending.cell, npcOrderRewards = npcOrderRewards }
          end
        end
      end
    end,
  })
end

-- Backstop for rows whose reward *list* is present but an icon didn't resolve
-- (e.g. a currency the player hasn't "discovered" client-side yet -- its data
-- loads shortly after, signaled by CURRENCY_DISPLAY_UPDATE, see Core.lua). No
-- new request needed here, just re-run resolution against the cached list.
function Rewards.RetryIconResolution()
  if next(activeCells) == nil then return end

  for orderIDString, pending in pairs(activeCells) do
    if pending.npcOrderRewards and pending.cell.patronOrderScoutOrderID == orderIDString then
      if ShowRewardIcons(pending.cell, pending.npcOrderRewards) then
        activeCells[orderIDString] = nil
      end
    end
  end
end

local installed = false

-- Hooks Blizzard's Tip-column Populate so Patron orders with resolved rewards
-- show real icons instead of the generic "has rewards" chest icon. Wrapped in
-- pcall so a future WoW UI change to this internal can't break Blizzard's own
-- tip-column rendering -- only our own icon logic is at risk, not the game's UI.
function Rewards.Install()
  if installed then return end
  installed = true

  hooksecurefunc(ProfessionsCrafterTableCellCommissionMixin, "Populate", function(cell, rowData)
    local ok, err = pcall(function()
      local order = rowData.option
      local newOrderID = tostring(order.orderID)
      if cell.patronOrderScoutOrderID and cell.patronOrderScoutOrderID ~= newOrderID then
        activeCells[cell.patronOrderScoutOrderID] = nil
      end
      cell.patronOrderScoutOrderID = newOrderID

      local npcOrderRewards = order.npcOrderRewards
      if npcOrderRewards and #npcOrderRewards > 0 then
        if ShowRewardIcons(cell, npcOrderRewards) then
          activeCells[newOrderID] = nil
        else
          activeCells[newOrderID] = { cell = cell, npcOrderRewards = npcOrderRewards }
        end
      else
        HideRewardIcons(cell)
        activeCells[newOrderID] = { cell = cell, npcOrderRewards = nil }
        if not pollTicker then
          pollTicker = C_Timer.NewTicker(3, RequestPendingRewards)
        end
      end
    end)
    if not ok then
      geterrorhandler()(err)
    end
  end)
end
