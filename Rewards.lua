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
