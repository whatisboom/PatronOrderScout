local ADDON, ns = ...
local Reagents = {}
ns.Reagents = Reagents

-- Diffs a recipe's required reagent slots (from
-- C_TradeSkillUI.GetRecipeSchematic(...).reagentSlotSchematics) against what
-- the patron already provided (order.reagents, a CraftingOrderReagentInfo
-- list) and returns the raw CraftingReagent ({ itemID? or currencyID? }) for
-- each required slot the patron did NOT cover, sorted by slotIndex. Pure
-- logic -- no WoW API calls beyond the Blizzard-provided
-- ProfessionsUtil.IsReagentSlotRequired predicate -- so it's covered by
-- tests/run.lua the same way Rewards.resolve is.
function Reagents.ComputeMissing(reagentSlotSchematics, providedReagents)
  local providedBySlot = {}
  for _, info in ipairs(providedReagents or {}) do
    providedBySlot[info.slotIndex] = true
  end

  local requiredSlots = {}
  for _, slot in ipairs(reagentSlotSchematics or {}) do
    if ProfessionsUtil.IsReagentSlotRequired(slot) and not providedBySlot[slot.slotIndex] then
      table.insert(requiredSlots, slot)
    end
  end
  table.sort(requiredSlots, function(a, b) return a.slotIndex < b.slotIndex end)

  local missing = {}
  for _, slot in ipairs(requiredSlots) do
    local raw = slot.reagents and slot.reagents[1]
    if raw then
      table.insert(missing, raw)
    end
  end
  return missing
end

local function resolveReagent(raw)
  if raw.currencyID then
    return ns.Resolve.currency(raw.currencyID)
  end
  return ns.Resolve.item(raw.itemID)
end

local MAX_MISSING_ICONS = 8 -- generous upper bound on a recipe's required reagent slots

-- orderID (as a string -- see Rewards.lua for why) -> { cell, missing } for
-- any row still waiting on icon resolution. Unlike Rewards, there's no
-- "waiting on the list" state: C_TradeSkillUI.GetRecipeSchematic is a
-- synchronous local lookup against the crafter's own known recipe, not a
-- server round-trip -- only a missing reagent's icon/name data (via
-- ns.Resolve) can still be uncached client-side.
local activeCells = {}

local function OnIconEnter(iconFrame)
  GameTooltip:SetOwner(iconFrame, "ANCHOR_TOP")
  local raw = iconFrame.reagent
  if raw.currencyID then
    GameTooltip:SetCurrencyByID(raw.currencyID)
  else
    GameTooltip:SetItemByID(raw.itemID)
  end
  GameTooltip:Show()
end

local function OnIconLeave()
  GameTooltip:Hide()
end

-- Lazily creates the icon frames we show in place of the cell's stock
-- "All"/"Some"/"None" text. Unlike Rewards' Commission cell (which has a
-- dedicated RewardIcon texture child to anchor against), the Reagents cell
-- template has no equivalent inline child -- so icons anchor to the cell's
-- own RIGHT edge instead of a sibling frame's LEFT edge.
local function GetOrCreateIcons(cell)
  return ns.IconRow.GetOrCreate(cell, "patronOrderScoutMissingIcons", MAX_MISSING_ICONS,
    cell, "RIGHT", -4, OnIconEnter, OnIconLeave)
end

-- Shows icons for `missing` on `cell`, replacing the stock text. Returns
-- `complete` -- false if any missing reagent's icon came back nil (data not
-- cached client-side yet), so the caller knows to keep this cell pending.
local function ShowMissingIcons(cell, missing)
  local icons = GetOrCreateIcons(cell)
  cell.Text:Hide()

  local complete = true
  for i, iconFrame in ipairs(icons) do
    local raw = missing[i]
    if raw then
      local resolved = resolveReagent(raw)
      iconFrame.icon:SetTexture(resolved.icon)
      iconFrame.reagent = raw
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

-- Hides any missing-reagent icons on `cell` and restores its stock text
-- (already "All Provided" via the PROFESSIONS_COLUMN_REAGENTS_ALL override in
-- Core.lua). Used whenever nothing is missing, and when a pooled cell is
-- repopulated for an order we can't compute a missing list for (e.g. the
-- recipe schematic lookup came back nil) -- falling back to Blizzard's own
-- text rather than silently showing an empty cell.
local function HideMissingIcons(cell)
  ns.IconRow.HideAll(cell, "patronOrderScoutMissingIcons")
  cell.Text:Show()
end

-- Backstop for rows whose missing-reagent list is known but an icon didn't
-- resolve (e.g. an item whose data isn't cached client-side yet -- see
-- GET_ITEM_INFO_RECEIVED/CURRENCY_DISPLAY_UPDATE handling in Core.lua). No
-- new computation needed, just re-run icon resolution against the cached list.
function Reagents.RetryIconResolution()
  if next(activeCells) == nil then return end

  for orderIDString, pending in pairs(activeCells) do
    if pending.cell.patronOrderScoutOrderID == orderIDString then
      if ShowMissingIcons(pending.cell, pending.missing) then
        activeCells[orderIDString] = nil
      end
    end
  end
end

local installed = false

-- Hooks Blizzard's Reagents-column Populate/OnEnter so Patron orders show
-- real missing-reagent icons instead of plain "All"/"Some"/"None" text, with
-- a tooltip breakdown of what's still needed. Wrapped in pcall so a future
-- WoW UI change to these internals can't break Blizzard's own rendering --
-- only our own icon logic is at risk, not the game's UI.
function Reagents.Install()
  if installed then return end
  installed = true

  hooksecurefunc(ProfessionsCrafterTableCellReagentsMixin, "Populate", function(cell, rowData)
    local ok, err = pcall(function()
      local order = rowData.option
      local newOrderID = tostring(order.orderID)
      if cell.patronOrderScoutOrderID and cell.patronOrderScoutOrderID ~= newOrderID then
        activeCells[cell.patronOrderScoutOrderID] = nil
      end
      cell.patronOrderScoutOrderID = newOrderID

      local schematic = C_TradeSkillUI.GetRecipeSchematic(order.spellID, order.isRecraft)
      if not schematic then
        -- Recipe schematic lookup failed -- fall back to Blizzard's own
        -- stock text rather than guessing, so a bug here can't silently
        -- render an order as "All Provided".
        cell.patronOrderScoutMissing = nil
        HideMissingIcons(cell)
        activeCells[newOrderID] = nil
        return
      end

      local missing = Reagents.ComputeMissing(schematic.reagentSlotSchematics, order.reagents)
      cell.patronOrderScoutMissing = missing

      if #missing == 0 then
        HideMissingIcons(cell)
        activeCells[newOrderID] = nil
      elseif ShowMissingIcons(cell, missing) then
        activeCells[newOrderID] = nil
      else
        activeCells[newOrderID] = { cell = cell, missing = missing }
      end
    end)
    if not ok then
      geterrorhandler()(err)
    end
  end)

  hooksecurefunc(ProfessionsCrafterTableCellReagentsMixin, "OnEnter", function(cell)
    local ok, err = pcall(function()
      local missing = cell.patronOrderScoutMissing
      if not missing or #missing == 0 then return end

      GameTooltip:AddLine(" ")
      GameTooltip:AddLine(PROFESSIONS_COLUMN_HEADER_REAGENTS, 1, 0.82, 0)
      for _, raw in ipairs(missing) do
        local resolved = resolveReagent(raw)
        GameTooltip:AddLine("  " .. resolved.name, 1, 1, 1)
      end
      GameTooltip:Show()
    end)
    if not ok then
      geterrorhandler()(err)
    end
  end)
end
