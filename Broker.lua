local ADDON, ns = ...
local Broker = {}
ns.Broker = Broker

function Broker:Setup(addon)
  local LDB = LibStub("LibDataBroker-1.1")
  self.obj = LDB:NewDataObject("PatronOrderScout", {
    type = "data source",
    text = "Patron Orders",
    icon = "Interface\\Icons\\INV_Misc_QuestionMark",  -- guaranteed-render placeholder; theme once confirmed
    OnTooltipShow = function(tt) Broker:OnTooltip(tt) end,
  })
  self:Update()
end

function Broker:Current()
  return ns.Scanner:VisibleOrders(ns.addon.db.profile.filters)
end

function Broker:Update()
  if not self.obj then return end
  self.obj.text = ("Patron Orders: %d"):format(#self:Current())
end

function Broker:OnTooltip(tt)
  tt:AddLine("Patron Order Scout")
  local visible = self:Current()
  if #visible == 0 then
    tt:AddLine("No matching patron orders available.", 0.6, 0.6, 0.6)
  else
    for _, order in ipairs(visible) do
      local name = order.itemLink or "Unknown Order"
      tt:AddDoubleLine(name, ns.Format.orderRewardsText(order), 1, 1, 1, 0.6, 0.9, 0.6)
    end
  end
end
