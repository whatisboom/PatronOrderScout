local ADDON, ns = ...
local Rewards = {}
ns.Rewards = Rewards

-- Resolves one raw CraftingOrderRewardInfo ({ itemLink?, currencyType?, count })
-- into a display-ready shape. currencyType rewards get a plain/neutral border
-- (currencies have no quality); itemLink rewards get a real quality-colored
-- border via C_Item.GetItemQualityColor.
function Rewards.resolve(raw)
  if raw.currencyType then
    local info = C_CurrencyInfo.GetCurrencyInfo(raw.currencyType)
    return {
      kind = "currency",
      name = (info and info.name) or ("Currency " .. raw.currencyType),
      icon = info and info.iconFileID,
      borderColor = { 0.5, 0.5, 0.5 },
    }
  end

  local name, _, quality, _, _, _, _, _, _, icon = C_Item.GetItemInfo(raw.itemLink)
  local r, g, b = C_Item.GetItemQualityColor(quality or 1)
  return {
    kind = "item",
    name = name or raw.itemLink or "Unknown Item",
    icon = icon,
    borderColor = { r, g, b },
  }
end

local MAX_REWARD_ICONS = 2 -- NPC_CRAFTING_ORDER_NUM_SUPPORTED_REWARDS

-- orderID (as a string -- BigUInteger values aren't safe to use as table keys
-- directly, see Core.lua) -> the cell frame currently showing that order's Tip
-- column, so a late-arriving CRAFTINGORDERS_UPDATE_REWARDS event can refresh it.
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
  if cell.patronOrderScoutIcons then return cell.patronOrderScoutIcons end

  local icons = {}
  for i = 1, MAX_REWARD_ICONS do
    local iconFrame = CreateFrame("Frame", nil, cell)
    iconFrame:SetSize(16, 16)
    if i == 1 then
      iconFrame:SetPoint("RIGHT", cell.TipMoneyDisplayFrame, "LEFT", -5, 0)
    else
      iconFrame:SetPoint("RIGHT", icons[i - 1], "LEFT", -2, 0)
    end
    iconFrame:EnableMouse(true)

    -- Border is drawn BACKGROUND (behind ARTWORK) and 1px larger on each side,
    -- so it reads as a colored ring around the icon.
    iconFrame.border = iconFrame:CreateTexture(nil, "BACKGROUND")
    iconFrame.border:SetColorTexture(1, 1, 1, 1)
    iconFrame.border:SetPoint("TOPLEFT", iconFrame, "TOPLEFT", -1, 1)
    iconFrame.border:SetPoint("BOTTOMRIGHT", iconFrame, "BOTTOMRIGHT", 1, -1)

    iconFrame.icon = iconFrame:CreateTexture(nil, "ARTWORK")
    iconFrame.icon:SetAllPoints()

    iconFrame:SetScript("OnEnter", OnIconEnter)
    iconFrame:SetScript("OnLeave", OnIconLeave)

    iconFrame:Hide()
    icons[i] = iconFrame
  end

  cell.patronOrderScoutIcons = icons
  return icons
end

-- Shows up to MAX_REWARD_ICONS real reward icons on `cell`, replacing
-- Blizzard's generic chest icon.
local function ShowRewardIcons(cell, npcOrderRewards)
  local icons = GetOrCreateIcons(cell)
  cell.RewardIcon:Hide()

  for i, iconFrame in ipairs(icons) do
    local raw = npcOrderRewards[i]
    if raw then
      local resolved = Rewards.resolve(raw)
      iconFrame.icon:SetTexture(resolved.icon)
      iconFrame.border:SetColorTexture(resolved.borderColor[1], resolved.borderColor[2], resolved.borderColor[3], 1)
      iconFrame.reward = raw
      iconFrame:Show()
    else
      iconFrame:Hide()
    end
  end
end

-- Refreshes a cell already displaying `orderID`, if any, with newly-arrived
-- reward data (see CRAFTINGORDERS_UPDATE_REWARDS handling in Core.lua).
function Rewards.OnRewardsUpdated(orderIDString, npcOrderRewards)
  local cell = activeCells[orderIDString]
  if cell and npcOrderRewards and #npcOrderRewards > 0 then
    ShowRewardIcons(cell, npcOrderRewards)
  end
end

-- Hooks Blizzard's Tip-column Populate so Patron orders with resolved rewards
-- show real icons instead of the generic "has rewards" chest icon. Wrapped in
-- pcall so a future WoW UI change to this internal can't break Blizzard's own
-- tip-column rendering -- only our own icon logic is at risk, not the game's UI.
function Rewards.Install()
  hooksecurefunc(ProfessionsCrafterTableCellCommissionMixin, "Populate", function(cell, rowData)
    local ok, err = pcall(function()
      local order = rowData.option
      activeCells[tostring(order.orderID)] = cell

      local npcOrderRewards = order.npcOrderRewards
      if npcOrderRewards and #npcOrderRewards > 0 then
        ShowRewardIcons(cell, npcOrderRewards)
      end
    end)
    if not ok then
      geterrorhandler()(err)
    end
  end)
end
