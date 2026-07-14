local ADDON, ns = ...

local PatronOrderScout = LibStub("AceAddon-3.0"):NewAddon("PatronOrderScout", "AceEvent-3.0")
ns.addon = PatronOrderScout

function PatronOrderScout:OnInitialize()
  local entry = BoomForge:RegisterPlugin(self, {
    name = "PatronOrderScout",
    version = C_AddOns.GetAddOnMetadata(ADDON, "Version"),
  })
  ns.log = entry.services.log
end

function PatronOrderScout:OnEnable()
  self:RegisterEvent("CRAFTINGORDERS_UPDATE_REWARDS", "OnRewardsUpdated")

  -- ProfessionsCrafterTableCellCommissionMixin (Rewards.Install's hook target)
  -- lives in Blizzard_ProfessionsTemplates, which is load-on-demand -- it isn't
  -- loaded at login, only once the player opens the Professions UI. If it's
  -- already loaded (e.g. after a UI reload with the profession window left
  -- open), install immediately; otherwise wait for it to load.
  if ProfessionsCrafterTableCellCommissionMixin then
    ns.Rewards.Install()
  else
    self:RegisterEvent("ADDON_LOADED", "OnAddonLoaded")
  end
end

function PatronOrderScout:OnAddonLoaded(event, addonName)
  if addonName ~= "Blizzard_ProfessionsTemplates" then return end
  self:UnregisterEvent("ADDON_LOADED")
  ns.Rewards.Install()
end

-- npcOrderRewards can arrive after a row's Tip column has already been
-- populated; refresh just that row's icons in place rather than re-requesting.
function PatronOrderScout:OnRewardsUpdated(event, npcOrderRewards, orderID)
  ns.Rewards.OnRewardsUpdated(tostring(orderID), npcOrderRewards)
end
