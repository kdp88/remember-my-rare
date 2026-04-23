-- RememberMyRare — Events
-- Detects rare kills using a two-event correlation pattern:
--   1. PLAYER_TARGET_CHANGED  — caches rare target info (classification available here)
--   2. COMBAT_LOG_EVENT_UNFILTERED UNIT_DIED — confirms kill by matching GUID
--
-- All event registration happens at file scope (safe in WoW 12.0).
-- Handlers silently ignore events until Init() marks the addon as ready.

local Events = RMR.Events

-- Guards all handlers — set to true by Init() once SavedVariables are ready.
local initialized = false

-- In-memory cache of rare targets the player has targeted this session.
-- { [guid] = { npcID, name, mapID, x, y } }
local pendingRares = {}

-- Extracts the NPC ID from a WoW creature GUID.
-- GUID format: "Creature-0-REALM-SERVER-INSTANCE-NPCID-SPAWNUID"
local function ExtractNPCID(guid)
    if not guid or not guid:find("Creature") then return nil end
    return tonumber((select(6, strsplit("-", guid))))
end

local function OnTargetChanged()
    if not initialized then return end

    local guid = UnitGUID("target")
    if not guid then return end

    local classification = UnitClassification("target")
    if classification ~= "rare" and classification ~= "rareelite" then return end

    local npcID = ExtractNPCID(guid)
    if not npcID then return end

    local mapID = C_Map.GetBestMapForUnit("player")
    if not mapID then return end

    local pos = C_Map.GetPlayerMapPosition(mapID, "player")
    if not pos then return end

    pendingRares[guid] = {
        npcID = npcID,
        name  = UnitName("target") or "Unknown Rare",
        mapID = mapID,
        x     = pos.x,
        y     = pos.y,
    }
end

local function OnUnitDied(unitToken)
    if not initialized then return end
    if next(pendingRares) == nil then return end

    -- For world creatures UNIT_DIED passes the GUID directly as the token.
    -- For named units ("target", "focus", etc.) we need UnitGUID().
    local guid = UnitGUID(unitToken) or unitToken
    if not guid then return end

    local data = pendingRares[guid]
    if not data then return end

    data.timestamp = GetServerTime()
    RMR.Data:RecordKill(data)
    pendingRares[guid] = nil

    -- Pass the stored DB record (not the raw cache) so pins have killCount.
    local stored = RMR_DB.kills[RMR.Data:Key(data.mapID, data.npcID)]
    RMR.WorldMap:AddPin(stored)
    RMR.Minimap:AddPin(stored)

    print("|cFF00FF00RememberMyRare|r: Recorded " .. data.name .. " kill.")
end

local function OnEnteringWorld()
    if not initialized then return end
    wipe(pendingRares)
end

-- Register all events at file scope — safe in all WoW versions.
local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("PLAYER_TARGET_CHANGED")
eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
eventFrame:RegisterEvent("UNIT_DIED")
eventFrame:SetScript("OnEvent", function(_, event, ...)
    if event == "PLAYER_TARGET_CHANGED" then
        OnTargetChanged()
    elseif event == "UNIT_DIED" then
        OnUnitDied(...)
    elseif event == "PLAYER_ENTERING_WORLD" then
        OnEnteringWorld()
    end
end)

-- Called by Core.lua once SavedVariables are initialised.
function Events:Init()
    initialized = true
end
