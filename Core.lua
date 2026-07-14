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
  -- A reward's icon can come back nil if its underlying currency/item data
  -- isn't cached client-side yet -- CURRENCY_DISPLAY_UPDATE and
  -- GET_ITEM_INFO_RECEIVED fire once that data loads. Confirmed via diagnostic
  -- logging that item-type rewards (raw.itemLink with an empty "[]" name) are
  -- the case actually seen in practice, not currency discovery -- keeping both
  -- handlers since either can happen and retrying is cheap/idempotent.
  self:RegisterEvent("CURRENCY_DISPLAY_UPDATE", "OnRewardDataLoaded")
  self:RegisterEvent("GET_ITEM_INFO_RECEIVED", "OnRewardDataLoaded")

  -- ProfessionsCrafterTableCellCommissionMixin (Rewards.Install's hook target)
  -- lives in Blizzard_ProfessionsTemplates, which is load-on-demand -- it isn't
  -- loaded at login unless something forces it. Force-load it now rather than
  -- waiting for the player to open the Professions UI: waiting passively meant
  -- our hook could install a moment too late to catch the very first Populate
  -- pass on the Patron tab (hooksecurefunc only affects calls made after it's
  -- installed), so those rows' reward icons never appeared until something
  -- else happened to re-trigger Populate (e.g. switching tabs away and back).
  C_AddOns.LoadAddOn("Blizzard_ProfessionsTemplates")

  if ProfessionsCrafterTableCellCommissionMixin then
    ns.Rewards.Install()
  else
    -- Load-on-demand fell back (e.g. the user disabled that Blizzard addon) --
    -- install once it does load, same as the previous behavior.
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

function PatronOrderScout:OnRewardDataLoaded()
  ns.Rewards.RetryIconResolution()
end
