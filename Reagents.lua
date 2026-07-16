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

-- Adds a gold section-header line ("Provided"/"Missing") to the tooltip.
-- GameTooltip:AddLine renders whichever line lands first on the tooltip in
-- Blizzard's larger header font automatically, and every line after that in
-- the normal body font -- since either "Provided" or "Missing" can end up
-- being that first line depending on the order (e.g. "Missing" is first when
-- nothing was provided), both headers force the same (body) font explicitly
-- so they always match each other regardless of which one lands first.
local function AddSectionHeader(text)
  GameTooltip:AddLine(text, 1, 0.82, 0)
  local fontString = _G["GameTooltipTextLeft" .. GameTooltip:NumLines()]
  if fontString then
    fontString:SetFontObject(GameTooltipText)
  end
end

-- Lazily creates the icon frames we show in place of the cell's stock
-- "All"/"Some"/"None" text. Unlike Rewards' Commission cell (which has a
-- dedicated RewardIcon texture child to anchor against), the Reagents cell
-- template has no equivalent inline child -- so icons anchor to the cell's
-- own RIGHT edge instead of a sibling frame's LEFT edge.
local function GetOrCreateIcons(cell)
  return ns.IconRow.GetOrCreate(cell, "patronOrderScoutMissingIcons", MAX_MISSING_ICONS,
    cell, "RIGHT", -4, "left", OnIconEnter, OnIconLeave)
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
-- Core.lua). Right-justified and inset by the same -4px the missing-reagent
-- icons use (see GetOrCreateIcons) so the text's right edge lines up exactly
-- with where those icons sit when this same cell shows icons for a different
-- order -- the template's default setAllPoints=true has no inset, which left
-- the text a few pixels further right than the icons. Used whenever nothing
-- is missing, and when a pooled cell is repopulated for an order we can't
-- compute a missing list for (e.g. the recipe schematic lookup came back
-- nil) -- falling back to Blizzard's own text rather than silently showing
-- an empty cell.
local function HideMissingIcons(cell)
  ns.IconRow.HideAll(cell, "patronOrderScoutMissingIcons")
  cell.Text:ClearAllPoints()
  cell.Text:SetPoint("TOPLEFT", cell, "TOPLEFT", 0, 0)
  cell.Text:SetPoint("BOTTOMRIGHT", cell, "BOTTOMRIGHT", -4, 0)
  cell.Text:SetJustifyH("RIGHT")
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

-- Hooks Blizzard's Reagents-column Populate (hooksecurefunc) and replaces its
-- OnEnter (see comment below for why) so Patron orders show real
-- missing-reagent icons instead of plain "All"/"Some"/"None" text, with a
-- tooltip broken into "Provided:"/"Missing" sections. Populate's hook is
-- pcall-wrapped so a future WoW UI change to that internal can't break
-- Blizzard's own rendering -- only our own icon logic is at risk, not the
-- game's UI.
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
      cell.patronOrderScoutHasProvided = order.reagents ~= nil and #order.reagents > 0

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

  -- OnEnter needs a line prepended BEFORE Blizzard's own tooltip content
  -- (the provided-reagents icon row), which hooksecurefunc can't do -- it
  -- only ever runs after the hooked function returns. So this replaces
  -- OnEnter outright rather than hooking it, unlike every other Blizzard
  -- function this addon touches.
  --
  -- That alone isn't enough, though: Blizzard's original OnEnter calls
  -- GameTooltip:SetOwner(self, "ANCHOR_RIGHT") itself before inserting its
  -- icon frame -- and SetOwner clears any lines already on the tooltip, even
  -- when called again with the same owner/anchor (confirmed empirically --
  -- our "Provided:" line was silently wiped by Blizzard's own SetOwner
  -- call). There's no GameTooltip API to insert a line before content that
  -- already exists, so the only way to get our header above Blizzard's icon
  -- row -- short of reimplementing its ~50 lines of reagent-icon-pool logic
  -- ourselves -- is to make that second SetOwner call a no-op for the single
  -- owner (this cell) it'll be called with, for the duration of Blizzard's
  -- own handler only. Scoped narrowly and always restored immediately after,
  -- whether or not Blizzard's handler errors.
  local originalOnEnter = ProfessionsCrafterTableCellReagentsMixin.OnEnter
  ProfessionsCrafterTableCellReagentsMixin.OnEnter = function(cell)
    local realSetOwner = GameTooltip.SetOwner
    local patchedSetOwner = false

    local ok, err = pcall(function()
      if cell.patronOrderScoutHasProvided then
        GameTooltip:SetOwner(cell, "ANCHOR_RIGHT")
        AddSectionHeader("Provided")
        GameTooltip.SetOwner = function(tooltip, owner, ...)
          if owner == cell then return end
          return realSetOwner(tooltip, owner, ...)
        end
        patchedSetOwner = true
      end
    end)
    if not ok then
      geterrorhandler()(err)
    end

    local innerOk, innerErr = pcall(originalOnEnter, cell)
    if patchedSetOwner then
      GameTooltip.SetOwner = realSetOwner
    end
    if not innerOk then
      geterrorhandler()(innerErr)
    end

    local ok2, err2 = pcall(function()
      local missing = cell.patronOrderScoutMissing
      if not missing or #missing == 0 then return end

      GameTooltip:AddLine(" ")
      AddSectionHeader(PROFESSIONS_COLUMN_HEADER_REAGENTS)
      for _, raw in ipairs(missing) do
        local resolved = resolveReagent(raw)
        GameTooltip:AddLine("  " .. resolved.name, 1, 1, 1)
      end
      GameTooltip:Show()
    end)
    if not ok2 then
      geterrorhandler()(err2)
    end
  end
end
