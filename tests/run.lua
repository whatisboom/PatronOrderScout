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

print(("\n%d passed, %d failed"):format(passed, failed))
if failed > 0 then os.exit(1) end
