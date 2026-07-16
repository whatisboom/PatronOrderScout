local ADDON, ns = ...
local IconRow = {}
ns.IconRow = IconRow

-- Lazily creates (once per pooled cell frame, since TableBuilder cells are
-- reused across rows as the list scrolls) a row of icon frames growing away
-- from an initial anchor, in `direction` ("left" or "right"). `key` is the
-- field name used to stash the row on `cell`, letting a cell host more than
-- one such row without collisions. The first icon anchors to
-- `anchorRelativePoint` on `anchorFrame`, offset by `xOffset` (e.g. anchoring
-- to a sibling frame's edge, or to the cell's own edge when there's no
-- dedicated sibling to anchor against). Every icon after the first always
-- chains to the previous icon with fixed spacing in the same direction,
-- regardless of how the first icon was anchored.
function IconRow.GetOrCreate(cell, key, maxIcons, anchorFrame, anchorRelativePoint, xOffset, direction, onEnter, onLeave)
  if cell[key] then return cell[key] end

  local point = (direction == "right") and "LEFT" or "RIGHT"
  local chainRelativePoint = (direction == "right") and "RIGHT" or "LEFT"
  local chainOffset = (direction == "right") and 5 or -5

  local icons = {}
  for i = 1, maxIcons do
    local iconFrame = CreateFrame("Frame", nil, cell)
    iconFrame:SetSize(16, 16)
    if i == 1 then
      iconFrame:SetPoint(point, anchorFrame, anchorRelativePoint, xOffset, 0)
    else
      iconFrame:SetPoint(point, icons[i - 1], chainRelativePoint, chainOffset, 0)
    end
    iconFrame:EnableMouse(true)

    iconFrame.icon = iconFrame:CreateTexture(nil, "ARTWORK")
    iconFrame.icon:SetAllPoints()

    iconFrame:SetScript("OnEnter", onEnter)
    iconFrame:SetScript("OnLeave", onLeave)

    iconFrame:Hide()
    icons[i] = iconFrame
  end

  cell[key] = icons
  return icons
end

-- Hides every icon frame in `icons` (a row previously returned by
-- GetOrCreate), if any exists yet on this cell.
function IconRow.HideAll(cell, key)
  local icons = cell[key]
  if not icons then return end
  for _, iconFrame in ipairs(icons) do
    iconFrame:Hide()
  end
end
