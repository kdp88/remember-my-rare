-- tests/test_pins.lua
-- Tests for Minimap.lua and WorldMap.lua:
--   • RMR_DB.hidden guard in AddPin / Refresh
--   • Proximity fade OnUpdate logic

local lu = require("luaunit")

local ADDON_ROOT = (debug.getinfo(1, "S").source:match("^@(.*[/\\])") or arg[0]:match("(.*[/\\])") or "") .. "../"

dofile(ADDON_ROOT .. "tests/mocks.lua")
ResetDB()
dofile(ADDON_ROOT .. "Data.lua")

-- Track the proximity frame created at Minimap.lua module scope.
ResetFrames()
dofile(ADDON_ROOT .. "Minimap.lua")
dofile(ADDON_ROOT .. "WorldMap.lua")

-- The proximity frame is the only plain "Frame" with an OnUpdate script.
local proximityFrame
for _, f in ipairs(_G._createdFrames) do
    if f._scripts["OnUpdate"] then
        proximityFrame = f
        break
    end
end

RMR.Minimap:Init()
RMR.WorldMap:Init()

-- Save real implementations so setUp can restore them if earlier test suites
-- (e.g. events tests) replace them with stubs on RMR.Minimap/WorldMap.
local _realMinimapRefresh  = RMR.Minimap.Refresh
local _realMinimapAddPin   = RMR.Minimap.AddPin
local _realWorldMapRefresh = RMR.WorldMap.Refresh
local _realWorldMapAddPin  = RMR.WorldMap.AddPin

-- ─── Helpers ───────────────────────────────────────────────────────────────

local TEST_MAP_ID = 2023
local TEST_KILL   = {
    npcID     = 12345,
    name      = "TestRare",
    mapID     = TEST_MAP_ID,
    x         = 0.50,
    y         = 0.50,
    timestamp = 1000,
    killCount = 1,
}

-- Returns the first active pin frame (has kill set) or nil.
local function activePin()
    for _, f in ipairs(_G._createdFrames) do
        if f.kill then return f end
    end
end

-- Flush proximityElapsed back to 0 by firing a full-second tick.
-- Safe when activePins is empty (no alpha side-effects).
local function resetProximityElapsed()
    proximityFrame:FireOnUpdate(2.0)
end

-- ─── TestMinimapHiddenGuard ────────────────────────────────────────────────

TestMinimapHiddenGuard = {}

function TestMinimapHiddenGuard:setUp()
    ResetDB()
    ResetPinCalls()
    RMR.Minimap.Refresh = _realMinimapRefresh
    RMR.Minimap.AddPin  = _realMinimapAddPin
    RMR.Minimap:Refresh()
end

function TestMinimapHiddenGuard:test_addpin_skipped_when_hidden()
    RMR_DB.hidden = true
    RMR.Minimap:AddPin(TEST_KILL)
    lu.assertEquals(#_G._hbdPinsCalls.minimap, 0)
end

function TestMinimapHiddenGuard:test_addpin_registers_pin_when_visible()
    RMR_DB.hidden = false
    RMR.Minimap:AddPin(TEST_KILL)
    lu.assertEquals(#_G._hbdPinsCalls.minimap, 1)
end

function TestMinimapHiddenGuard:test_refresh_adds_no_pins_when_hidden()
    RMR_DB.kills["2023:12345"] = TEST_KILL
    RMR_DB.hidden = true
    RMR.Minimap:Refresh()
    lu.assertEquals(#_G._hbdPinsCalls.minimap, 0)
end

function TestMinimapHiddenGuard:test_refresh_adds_pins_when_visible()
    RMR_DB.kills["2023:12345"] = TEST_KILL
    RMR_DB.hidden = false
    RMR.Minimap:Refresh()
    lu.assertEquals(#_G._hbdPinsCalls.minimap, 1)
end

function TestMinimapHiddenGuard:test_refresh_clears_existing_pins_even_when_hidden()
    -- First build some pins while visible.
    RMR_DB.kills["2023:12345"] = TEST_KILL
    RMR_DB.hidden = false
    RMR.Minimap:Refresh()
    local before = #_G._hbdPinsCalls.minimap

    -- Toggle hidden and refresh — teardown must still happen (no orphan pins).
    ResetPinCalls()
    RMR_DB.hidden = true
    RMR.Minimap:Refresh()

    -- No new AddMinimapIconMap calls, but also no crash.
    lu.assertEquals(#_G._hbdPinsCalls.minimap, 0)
    lu.assertEquals(before, 1)  -- sanity: first refresh did add a pin
end

-- ─── TestWorldMapHiddenGuard ───────────────────────────────────────────────

TestWorldMapHiddenGuard = {}

function TestWorldMapHiddenGuard:setUp()
    ResetDB()
    ResetPinCalls()
    RMR.WorldMap.Refresh = _realWorldMapRefresh
    RMR.WorldMap.AddPin  = _realWorldMapAddPin
    RMR.WorldMap:Refresh()
end

function TestWorldMapHiddenGuard:test_addpin_skipped_when_hidden()
    RMR_DB.hidden = true
    RMR.WorldMap:AddPin(TEST_KILL)
    lu.assertEquals(#_G._hbdPinsCalls.worldmap, 0)
end

function TestWorldMapHiddenGuard:test_addpin_registers_pin_when_visible()
    RMR_DB.hidden = false
    RMR.WorldMap:AddPin(TEST_KILL)
    lu.assertEquals(#_G._hbdPinsCalls.worldmap, 1)
end

function TestWorldMapHiddenGuard:test_refresh_adds_no_pins_when_hidden()
    RMR_DB.kills["2023:12345"] = TEST_KILL
    RMR_DB.hidden = true
    RMR.WorldMap:Refresh()
    lu.assertEquals(#_G._hbdPinsCalls.worldmap, 0)
end

function TestWorldMapHiddenGuard:test_refresh_adds_pins_when_visible()
    RMR_DB.kills["2023:12345"] = TEST_KILL
    RMR_DB.hidden = false
    RMR.WorldMap:Refresh()
    lu.assertEquals(#_G._hbdPinsCalls.worldmap, 1)
end

-- ─── TestProximityFade ─────────────────────────────────────────────────────

TestProximityFade = {}

function TestProximityFade:setUp()
    ResetDB()
    ResetPinCalls()
    RMR_DB.hidden = false
    RMR.Minimap.Refresh = _realMinimapRefresh
    RMR.Minimap.AddPin  = _realMinimapAddPin
    -- Seed one kill and build active pins.
    RMR_DB.kills["2023:12345"] = TEST_KILL
    RMR.Minimap:Refresh()
    -- Flush proximity elapsed so tests start from a known zero.
    resetProximityElapsed()
end

function TestProximityFade:test_pin_fades_when_player_is_near()
    C_Map.GetBestMapForUnit    = function() return TEST_MAP_ID end
    C_Map.GetPlayerMapPosition = function()
        -- Offset by 0.03 — well within NEAR_THRESHOLD of 0.08.
        return { x = TEST_KILL.x + 0.03, y = TEST_KILL.y + 0.03 }
    end
    proximityFrame:FireOnUpdate(1.0)
    lu.assertAlmostEquals(activePin()._alpha, 0.2, 0.001)
end

function TestProximityFade:test_pin_bright_when_player_is_far()
    C_Map.GetBestMapForUnit    = function() return TEST_MAP_ID end
    C_Map.GetPlayerMapPosition = function()
        -- Offset by 0.10 — beyond NEAR_THRESHOLD.
        return { x = TEST_KILL.x + 0.10, y = TEST_KILL.y + 0.0 }
    end
    proximityFrame:FireOnUpdate(1.0)
    lu.assertAlmostEquals(activePin()._alpha, 1.0, 0.001)
end

function TestProximityFade:test_pin_bright_when_on_different_map()
    C_Map.GetBestMapForUnit    = function() return 9999 end  -- different map
    C_Map.GetPlayerMapPosition = function()
        return { x = TEST_KILL.x, y = TEST_KILL.y }
    end
    -- Pre-dim the pin to make sure the update resets it.
    activePin()._alpha = 0.2
    proximityFrame:FireOnUpdate(1.0)
    lu.assertAlmostEquals(activePin()._alpha, 1.0, 0.001)
end

function TestProximityFade:test_no_update_before_1_second()
    C_Map.GetBestMapForUnit    = function() return TEST_MAP_ID end
    C_Map.GetPlayerMapPosition = function()
        return { x = TEST_KILL.x + 0.01, y = TEST_KILL.y }  -- near
    end
    activePin()._alpha = 1.0
    -- Fire three sub-second ticks totalling < 1 s.
    proximityFrame:FireOnUpdate(0.3)
    proximityFrame:FireOnUpdate(0.3)
    proximityFrame:FireOnUpdate(0.3)
    -- Alpha should be unchanged — throttle has not fired yet.
    lu.assertAlmostEquals(activePin()._alpha, 1.0, 0.001)
end

function TestProximityFade:test_no_crash_when_map_unavailable()
    C_Map.GetBestMapForUnit    = function() return nil end
    C_Map.GetPlayerMapPosition = function() return nil end
    -- Should not raise an error.
    proximityFrame:FireOnUpdate(1.0)
    lu.assertTrue(true)
end

function TestProximityFade:test_no_crash_when_position_unavailable()
    C_Map.GetBestMapForUnit    = function() return TEST_MAP_ID end
    C_Map.GetPlayerMapPosition = function() return nil end
    proximityFrame:FireOnUpdate(1.0)
    lu.assertTrue(true)
end
