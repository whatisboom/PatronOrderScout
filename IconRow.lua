local ADDON, ns = ...
local IconRow = {}
ns.IconRow = IconRow

-- Lazily creates (once per pooled cell frame, since TableBuilder cells are
-- reused across rows as the list scrolls) a row of icon frames growing
-- leftward from an initial anchor. `key` is the field name used to stash the
-- row on `cell`, letting a cell host more than one such row without
-- collisions. The first icon anchors its RIGHT to `anchorRelativePoint` on
-- `anchorFrame`, offset by `xOffset` (e.g. anchoring to a sibling frame's
-- LEFT edge, or to the cell's own RIGHT edge when there's no dedicated
-- sibling to anchor against). Every icon after the first always chains to
-- the previous icon's LEFT edge with fixed spacing, regardless of how the
-- first icon was anchored.
function IconRow.GetOrCreate(cell, key, maxIcons, anchorFrame, anchorRelativePoint, xOffset, onEnter, onLeave)
  if cell[key] then return cell[key] end

  local icons = {}
  for i = 1, maxIcons do
    local iconFrame = CreateFrame("Frame", nil, cell)
    iconFrame:SetSize(16, 16)
    if i == 1 then
      iconFrame:SetPoint("RIGHT", anchorFrame, anchorRelativePoint, xOffset, 0)
    else
      iconFrame:SetPoint("RIGHT", icons[i - 1], "LEFT", -5, 0)
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
