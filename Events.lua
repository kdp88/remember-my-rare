-- RememberMyRare — Events
-- Detects rare kills using a two-event correlation pattern:
--   1. PLAYER_TARGET_CHANGED  — caches rare target info (classification available here)
--   2. COMBAT_LOG_EVENT_UNFILTERED UNIT_DIED — confirms kill by matching GUID
--
-- COMBAT_LOG_EVENT_UNFILTERED fires hundreds of times per second in combat.
-- We only register it while pendingRares is non-empty to minimise overhead.

local Events = RMR.Events

-- In-memory cache of rare targets the player has targeted this session.
-- { [guid] = { npcID, name, mapID, x, y } }
local pendingRares = {}

local eventFrame  -- set in Init(), used to register/unregister dynamically

-- Extracts the NPC ID from a WoW creature GUID.
-- GUID format: "Creature-0-REALM-SERVER-INSTANCE-NPCID-SPAWNUID"
local function ExtractNPCID(guid)
    if not guid or not guid:find("Creature") then return nil end
    return tonumber((select(6, strsplit("-", guid))))
end

local function OnTargetChanged()
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

    local wasEmpty = (next(pendingRares) == nil)
    pendingRares[guid] = {
        npcID = npcID,
        name  = UnitName("target") or "Unknown Rare",
        mapID = mapID,
        x     = pos.x,
        y     = pos.y,
    }

    -- Start listening for UNIT_DIED only now that we have a rare to watch for.
    if wasEmpty then
        eventFrame:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
    end
end

local function OnCombatLog()
    local _, event, _, _, _, _, _, destGUID = CombatLogGetCurrentEventInfo()
    if event ~= "UNIT_DIED" then return end

    local data = pendingRares[destGUID]
    if not data then return end

    data.timestamp = GetServerTime()
    RMR.Data:RecordKill(data)
    pendingRares[destGUID] = nil

    -- Stop listening to the high-frequency event when no rares are pending.
    if next(pendingRares) == nil then
        eventFrame:UnregisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
    end

    -- Add the single new pin — avoids a full O(n) rebuild of all existing pins.
    RMR.WorldMap:AddPin(data)
    RMR.Minimap:AddPin(data)

    print("|cFF00FF00RememberMyRare|r: Recorded " .. data.name .. " kill.")
end

local function OnEnteringWorld()
    -- Stale pending targets from the previous zone are no longer valid.
    wipe(pendingRares)
    eventFrame:UnregisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
end

function Events:Init()
    eventFrame = CreateFrame("Frame")
    eventFrame:RegisterEvent("PLAYER_TARGET_CHANGED")
    eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
    -- NOTE: COMBAT_LOG_EVENT_UNFILTERED is registered on-demand in OnTargetChanged.
    eventFrame:SetScript("OnEvent", function(_, event)
        if event == "PLAYER_TARGET_CHANGED" then
            OnTargetChanged()
        elseif event == "COMBAT_LOG_EVENT_UNFILTERED" then
            OnCombatLog()
        elseif event == "PLAYER_ENTERING_WORLD" then
            OnEnteringWorld()
        end
    end)
end
