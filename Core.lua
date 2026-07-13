local ADDON, ns = ...

local PatronOrderScout = LibStub("AceAddon-3.0"):NewAddon("PatronOrderScout", "AceEvent-3.0", "AceTimer-3.0")
ns.addon = PatronOrderScout

-- filters: set of active reward-category filters (e.g. { knowledge = true }).
-- An empty set means "show all" (see Format.matchesFilter).
local defaults = { profile = { debugLevel = nil, filters = {} } }

function PatronOrderScout:OnInitialize()
  self.db = LibStub("AceDB-3.0"):New("PatronOrderScoutDB", defaults, true)

  local entry = BoomForge:RegisterPlugin(self, {
    name = "PatronOrderScout",
    version = "0.1.0",
    getLevel = function() return self.db.profile.debugLevel end,
  })
  ns.log = entry.services.log

  ns.Broker:Setup(self)
end

function PatronOrderScout:OnEnable()
  self:RegisterEvent("CRAFTINGORDERS_UPDATE_REWARDS", "OnRewardsUpdated")
  self:RegisterEvent("CRAFTINGORDERS_UPDATE_ORDER_COUNT", "OnOrderCountChanged")
  self:RegisterEvent("PLAYER_ENTERING_WORLD", "OnOrdersChanged")
  -- Patron orders can appear, get claimed by other crafters, or expire while
  -- logged in, so re-request periodically rather than only once at login --
  -- mirrors VaultTracker's periodic-refresh pattern.
  self.refreshTimer = self:ScheduleRepeatingTimer("OnOrdersChanged", 60)
  self:OnOrdersChanged()
end

-- Only PLAYER_ENTERING_WORLD and the periodic timer actively call
-- C_CraftingOrders.RequestCrafterOrders(). CRAFTINGORDERS_UPDATE_ORDER_COUNT is a
-- broadcast *result* of any order-count change (including our own requests and
-- Blizzard's own crafting-order frame's requests) -- the built-in "Patron (N)"
-- tab reads its count directly off this same event, so treating it as a "go
-- request again" trigger created a feedback loop that raced the built-in UI's
-- own request cycle and made its count flicker to 0. Just re-read the
-- already-updated local cache instead of issuing a new request.
function PatronOrderScout:OnOrderCountChanged()
  ns.Scanner:Scan()
  ns.Broker:Update()
end

function PatronOrderScout:OnOrdersChanged()
  ns.Scanner:RequestOrders()
end

-- npcOrderRewards can arrive after the initial order list is scanned; refresh
-- just that order's rewards and update the display rather than re-requesting.
function PatronOrderScout:OnRewardsUpdated(event, npcOrderRewards, orderID)
  ns.Scanner:SetRewards(orderID, npcOrderRewards)
  ns.Broker:Update()
end
