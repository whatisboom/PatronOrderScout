-- Standalone test runner. Run: lua tests/run.lua
-- Tests PatronOrderScout's pure-Lua modules (Rewards.lua's resolution logic)
-- outside the WoW client, the same way BoomForge/VaultTracker's tests/run.lua
-- test their pure-logic modules. The hooksecurefunc/frame/tooltip code in
-- Rewards.lua and Core.lua calls live WoW API and is verified manually in-game
-- instead.
local passed, failed = 0, 0

local function eq(actual, expected, msg)
  if actual == expected then passed = passed + 1
  else failed = failed + 1
    print(("FAIL: %s\n  expected %s, got %s"):format(msg, tostring(expected), tostring(actual)))
  end
end

-- Load a WoW addon file the same way WoW does: chunk(addonName, ns).
local function loadModule(path, ns)
  local chunk = assert(loadfile(path))
  chunk("PatronOrderScout", ns)
end

-- Shim the WoW globals Rewards.resolve calls, the same way BoomForge's own
-- tests/run.lua shims LibStub -- these don't exist outside the WoW client.
_G.C_CurrencyInfo = {
  GetCurrencyInfo = function(currencyType)
    if currencyType == 3008 then
      return { name = "Knowledge Points", iconFileID = 133784 }
    end
    return nil
  end,
}
_G.C_Item = {
  GetItemInfo = function(itemLink)
    if itemLink == "item:12345" then
      -- 18 return values per C_Item.GetItemInfo; quality is index 3, icon/texture is index 10.
      return "Crystallized Augment Rune", itemLink, 4, 70, 1, "Reagent", "", 1, "", 135884,
        0, 0, 0, 0, 0, 0, false, ""
    end
    return nil
  end,
  GetItemQualityColor = function(quality)
    if quality == 4 then return 0.64, 0.21, 0.93, "|cffa335ee" end -- epic purple
    return 1, 1, 1, "|cffffffff"
  end,
}

-- Reagents.ComputeMissing's only WoW-API dependency is this Blizzard-provided
-- predicate (ProfessionsUtil.lua:128, returns slot.required) -- shimmed the
-- same way C_CurrencyInfo/C_Item are, so the diff logic can run outside the
-- client.
_G.ProfessionsUtil = {
  IsReagentSlotRequired = function(slot) return slot.required end,
}

local ns = {}
loadModule("Resolve.lua", ns)
loadModule("Rewards.lua", ns)
local Rewards = ns.Rewards
loadModule("Reagents.lua", ns)
local Reagents = ns.Reagents

-- ---- Rewards.resolve ----
do
  local resolved = Rewards.resolve({ currencyType = 3008, count = 5 })
  eq(resolved.kind, "currency", "currency reward resolves kind as currency")
  eq(resolved.name, "Knowledge Points", "currency reward resolves its name via C_CurrencyInfo")
  eq(resolved.icon, 133784, "currency reward resolves its icon via C_CurrencyInfo")
  eq(resolved.borderColor[1], 0.5, "currency reward gets a neutral gray border (no item quality)")
end

do
  local resolved = Rewards.resolve({ itemLink = "item:12345", count = 1 })
  eq(resolved.kind, "item", "item reward resolves kind as item")
  eq(resolved.name, "Crystallized Augment Rune", "item reward resolves its name via C_Item.GetItemInfo")
  eq(resolved.icon, 135884, "item reward resolves its icon via C_Item.GetItemInfo (10th return value)")
  eq(resolved.borderColor[1], 0.64, "item reward's border color comes from C_Item.GetItemQualityColor(quality)")
end

-- ---- Reagents.ComputeMissing ----
do
  -- Two required slots, patron provided neither -- both come back missing,
  -- sorted by slotIndex.
  local schematic = {
    { slotIndex = 2, required = true, reagents = { { itemID = 222 } } },
    { slotIndex = 1, required = true, reagents = { { itemID = 111 } } },
  }
  local missing = Reagents.ComputeMissing(schematic, {})
  eq(#missing, 2, "both required slots missing when nothing provided")
  eq(missing[1].itemID, 111, "missing list is sorted by slotIndex")
  eq(missing[2].itemID, 222, "missing list is sorted by slotIndex")
end

do
  -- Patron provided slot 1; slot 2 remains missing.
  local schematic = {
    { slotIndex = 1, required = true, reagents = { { itemID = 111 } } },
    { slotIndex = 2, required = true, reagents = { { itemID = 222 } } },
  }
  local provided = { { slotIndex = 1, source = 0, isBasicReagent = true } }
  local missing = Reagents.ComputeMissing(schematic, provided)
  eq(#missing, 1, "only the unprovided required slot is missing")
  eq(missing[1].itemID, 222, "the missing slot's reagent is slot 2's")
end

do
  -- Optional/finishing slots (required == false) never count as missing.
  local schematic = {
    { slotIndex = 1, required = true, reagents = { { itemID = 111 } } },
    { slotIndex = 2, required = false, reagents = { { itemID = 999 } } },
  }
  local missing = Reagents.ComputeMissing(schematic, {})
  eq(#missing, 1, "optional/finishing slots are excluded from the missing list")
  eq(missing[1].itemID, 111, "only the required slot's reagent is reported missing")
end

do
  -- A currency-backed slot resolves via its currencyID field, not itemID.
  local schematic = {
    { slotIndex = 1, required = true, reagents = { { currencyID = 3008 } } },
  }
  local missing = Reagents.ComputeMissing(schematic, {})
  eq(#missing, 1, "currency-backed required slot is missing when unprovided")
  eq(missing[1].currencyID, 3008, "missing entry carries currencyID, not itemID")
end

do
  local missing = Reagents.ComputeMissing({}, {})
  eq(#missing, 0, "no reagent slots at all yields an empty missing list")
end

print(("\n%d passed, %d failed"):format(passed, failed))
if failed > 0 then os.exit(1) end
