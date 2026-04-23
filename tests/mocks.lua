-- tests/mocks.lua
-- Minimal WoW API stubs so addon Lua modules can be loaded and tested
-- outside of the game engine.  Import this before loading any addon files.

-- ─── Core WoW globals ──────────────────────────────────────────────────────

-- WoW's wipe() clears a table in-place (faster than reassignment in WoW).
wipe = function(t)
    for k in pairs(t) do t[k] = nil end
    return t
end

-- WoW's CopyTable() does a shallow copy (deep for nested tables in practice).
CopyTable = function(orig)
    local copy = {}
    for k, v in pairs(orig) do
        copy[k] = (type(v) == "table") and CopyTable(v) or v
    end
    return copy
end

-- WoW's strsplit(sep, str) returns each segment as a separate return value.
-- e.g. strsplit("-", "a-b-c") => "a", "b", "c"
strsplit = function(sep, str)
    local parts = {}
    -- Use a pattern that captures empty segments too.
    local pattern = string.format("([^%s]*)", sep)
    for part in (str .. sep):gmatch(pattern .. sep) do
        table.insert(parts, part)
    end
    return table.unpack(parts)
end

strtrim = function(s)
    return s:match("^%s*(.-)%s*$")
end

-- WoW's date() is os.date() with the same format string.
date = os.date

-- GetServerTime() returns the current Unix timestamp.
GetServerTime = function()
    return os.time()
end

-- ─── Frame factory ─────────────────────────────────────────────────────────
-- Returns a table that mimics a WoW Frame well enough for Init() calls.
-- Tests can call frame:FireEvent(event, ...) to simulate WoW firing events,
-- or frame:FireOnUpdate(dt) to simulate the engine's per-frame tick.

_G._createdFrames = {}

CreateFrame = function(frameType --[[, name, parent]])
    local frame = {
        _scripts   = {},
        _alpha     = 1.0,
        _visible   = false,
        _frameType = frameType or "Frame",
    }

    function frame:RegisterEvent() end
    function frame:UnregisterEvent() end
    function frame:SetScript(hook, fn) self._scripts[hook] = fn end
    function frame:GetScript(hook) return self._scripts[hook] end
    function frame:GetFrameLevel() return 1 end
    function frame:SetFrameLevel() end
    function frame:Show()  self._visible = true  end
    function frame:Hide()  self._visible = false end
    function frame:SetAlpha(a) self._alpha = a end
    function frame:GetAlpha()  return self._alpha end
    function frame:SetSize() end
    function frame:SetParent(p) self._parent = p end
    function frame:ClearAllPoints() end
    function frame:CreateTexture()
        return { SetAllPoints = function() end, SetTexture = function() end }
    end

    -- Test helpers
    function frame:FireEvent(event, ...)
        local fn = self._scripts["OnEvent"]
        if fn then fn(self, event, ...) end
    end
    function frame:FireOnUpdate(dt)
        local fn = self._scripts["OnUpdate"]
        if fn then fn(self, dt) end
    end

    table.insert(_G._createdFrames, frame)
    return frame
end

-- Stub needed by WorldMap.lua (pins are parented to UIParent).
UIParent = CreateFrame("Frame")

-- ─── Unit API stubs (overridden per test as needed) ────────────────────────

UnitGUID           = function() return nil end
UnitClassification = function() return "normal" end
UnitName           = function() return "Unknown" end

-- ─── C_Map stubs ───────────────────────────────────────────────────────────

C_Map = {
    GetBestMapForUnit    = function() return nil end,
    GetPlayerMapPosition = function() return nil end,
}

-- ─── Combat log stub ───────────────────────────────────────────────────────

_G._combatLogArgs = { 0, "SPELL_DAMAGE", false, "srcGUID", "Src", 0, 0, "destGUID", "Dest", 0, 0 }
CombatLogGetCurrentEventInfo = function()
    return table.unpack(_G._combatLogArgs)
end

-- ─── UI stubs ──────────────────────────────────────────────────────────────

-- WoW global slash-command registry.
SlashCmdList = {}

Minimap = { GetFrameLevel = function() return 1 end }

GameTooltip = {
    owner      = nil,
    lines      = {},
    SetOwner   = function(self, owner) self.owner = owner end,
    ClearLines = function(self) self.lines = {} end,
    AddLine    = function(self, text) table.insert(self.lines, text) end,
    AddDoubleLine = function(self, l, r)
        table.insert(self.lines, l .. "|" .. tostring(r))
    end,
    Show = function(self) self.visible = true end,
    Hide = function(self) self.visible = false end,
}

-- ─── HBDPins stub ──────────────────────────────────────────────────────────
-- Lightweight stub so WorldMap.lua and Minimap.lua load without errors.
-- Tests that exercise pin refresh behaviour use these call-count trackers.

_G._hbdPinsCalls = { worldmap = {}, minimap = {} }

LibStub = function(name)
    if name == "HereBeDragons-Pins-2.0" then
        return {
            AddWorldMapIconMap  = function(_, ref, pin, mapID, x, y)
                table.insert(_G._hbdPinsCalls.worldmap, { mapID=mapID, x=x, y=y })
            end,
            AddMinimapIconMap   = function(_, ref, pin, mapID, x, y)
                table.insert(_G._hbdPinsCalls.minimap,  { mapID=mapID, x=x, y=y })
            end,
            RemoveWorldMapIcon      = function() end,
            RemoveMinimapIcon       = function() end,
            RemoveAllWorldMapIcons  = function() end,
            RemoveAllMinimapIcons   = function() end,
        }
    end
    error("LibStub: unknown library " .. tostring(name))
end

-- Global show-flag constant used in WorldMap.lua
HBD_PINS_WORLDMAP_SHOW_CONTINENT = 2

-- ─── Addon namespace (populated by loading addon files) ────────────────────

RMR = {
    Data     = {},
    Events   = {},
    WorldMap = {},
    Minimap  = {},
    Tooltip  = {},
    Config   = {},
}

-- ─── Helpers ───────────────────────────────────────────────────────────────

-- Reset the in-memory database to a clean state between tests.
function ResetDB()
    RMR_DB = { version = 1, kills = {}, hidden = false }
end

-- Reset HBDPins call log.
function ResetPinCalls()
    _G._hbdPinsCalls = { worldmap = {}, minimap = {} }
end

-- Clear the frame registry (call before loading a module to track only its frames).
function ResetFrames()
    _G._createdFrames = {}
end
