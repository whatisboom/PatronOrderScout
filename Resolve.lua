local ADDON, ns = ...
local Resolve = {}
ns.Resolve = Resolve

-- Resolves an item (by link or numeric ID -- C_Item.GetItemInfo accepts
-- either) into a display-ready shape. `icon` can come back nil if the
-- underlying item data isn't cached client-side yet -- callers must handle
-- that, not assume a resolved item always has a usable icon.
function Resolve.item(itemLinkOrID)
  local name, _, quality, _, _, _, _, _, _, icon = C_Item.GetItemInfo(itemLinkOrID)
  local r, g, b = C_Item.GetItemQualityColor(quality or 1)
  return {
    kind = "item",
    name = name or tostring(itemLinkOrID) or "Unknown Item",
    icon = icon,
    borderColor = { r, g, b },
  }
end

-- Resolves a currency into a display-ready shape. Currencies get a
-- plain/neutral border since they have no quality. `icon` can come back nil
-- if the currency isn't "discovered" client-side yet.
function Resolve.currency(currencyID)
  local info = C_CurrencyInfo.GetCurrencyInfo(currencyID)
  return {
    kind = "currency",
    name = (info and info.name) or ("Currency " .. currencyID),
    icon = info and info.iconFileID,
    borderColor = { 0.5, 0.5, 0.5 },
  }
end
