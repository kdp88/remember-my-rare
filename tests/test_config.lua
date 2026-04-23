-- tests/test_config.lua
-- Unit tests for Config.lua — /rmr toggle command and help text.

local lu = require("luaunit")

local ADDON_ROOT = (debug.getinfo(1, "S").source:match("^@(.*[/\\])") or arg[0]:match("(.*[/\\])") or "") .. "../"

dofile(ADDON_ROOT .. "tests/mocks.lua")
ResetDB()
dofile(ADDON_ROOT .. "Data.lua")

-- Stub pin modules so Config.lua can call Refresh without loading the full UI.
local minimapRefreshCalled = false
local worldmapRefreshCalled = false

RMR.Minimap.Refresh  = function() minimapRefreshCalled  = true end
RMR.WorldMap.Refresh = function() worldmapRefreshCalled = true end
RMR.Minimap.AddPin   = function() end
RMR.WorldMap.AddPin  = function() end

-- Suppress chat output; tests inspect this table.
local printed = {}
print = function(msg) table.insert(printed, msg) end

dofile(ADDON_ROOT .. "Config.lua")
RMR.Config:Init()   -- registers SlashCmdList["REMEMBERMYRARE"]

local function cmd(input)
    SlashCmdList["REMEMBERMYRARE"](input)
end

-- ─── TestToggleCommand ─────────────────────────────────────────────────────

TestToggleCommand = {}

function TestToggleCommand:setUp()
    ResetDB()
    printed = {}
    print = function(msg) table.insert(printed, msg) end
    minimapRefreshCalled  = false
    worldmapRefreshCalled = false
    RMR.Minimap.Refresh  = function() minimapRefreshCalled  = true end
    RMR.WorldMap.Refresh = function() worldmapRefreshCalled = true end
    -- mocks reload (in test_pins.lua) resets RMR.Config = {} — reload the module first.
    dofile(ADDON_ROOT .. "Config.lua")
    RMR.Config:Init()
end

function TestToggleCommand:test_toggle_sets_hidden_true()
    lu.assertFalse(RMR_DB.hidden)
    cmd("toggle")
    lu.assertTrue(RMR_DB.hidden)
end

function TestToggleCommand:test_toggle_twice_restores_visible()
    cmd("toggle")
    cmd("toggle")
    lu.assertFalse(RMR_DB.hidden)
end

function TestToggleCommand:test_toggle_calls_minimap_refresh()
    cmd("toggle")
    lu.assertTrue(minimapRefreshCalled)
end

function TestToggleCommand:test_toggle_calls_worldmap_refresh()
    cmd("toggle")
    lu.assertTrue(worldmapRefreshCalled)
end

function TestToggleCommand:test_toggle_prints_hidden_when_hiding()
    cmd("toggle")
    lu.assertStrContains(printed[#printed], "hidden")
end

function TestToggleCommand:test_toggle_prints_visible_when_showing()
    cmd("toggle")   -- hide
    cmd("toggle")   -- show
    lu.assertStrContains(printed[#printed], "visible")
end

function TestToggleCommand:test_toggle_persists_value_after_refresh()
    cmd("toggle")
    -- Simulated Refresh wouldn't reset the flag.
    lu.assertTrue(RMR_DB.hidden)
end

-- ─── TestHelpCommand ───────────────────────────────────────────────────────

TestHelpCommand = {}

function TestHelpCommand:setUp()
    printed = {}
    print = function(msg) table.insert(printed, msg) end
    dofile(ADDON_ROOT .. "Config.lua")
    RMR.Config:Init()
end

function TestHelpCommand:test_help_includes_toggle_entry()
    cmd("unknowncommand")  -- any unknown input triggers PrintHelp
    local found = false
    for _, msg in ipairs(printed) do
        if msg:find("toggle") then found = true; break end
    end
    lu.assertTrue(found)
end
