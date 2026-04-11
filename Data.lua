-- RememberMyRare — Data
-- CRUD layer over RMR_DB.kills (account-wide SavedVariables).

local Data = RMR.Data

function Data:Init()
    -- RMR_DB already initialised and migrated by Core.lua; nothing to do here.
end

-- Composite key: "mapID:npcID" — one record per rare per zone.
function Data:Key(mapID, npcID)
    return tostring(mapID) .. ":" .. tostring(npcID)
end

-- Record a kill or update an existing one.
-- kill = { npcID, name, mapID, x, y, timestamp }
function Data:RecordKill(kill)
    local key      = self:Key(kill.mapID, kill.npcID)
    local existing = RMR_DB.kills[key]

    if existing then
        -- Update position to most-recent kill location and bump counter.
        existing.x         = kill.x
        existing.y         = kill.y
        existing.timestamp = kill.timestamp
        existing.killCount = existing.killCount + 1
    else
        RMR_DB.kills[key] = {
            npcID     = kill.npcID,
            name      = kill.name,
            mapID     = kill.mapID,
            x         = kill.x,
            y         = kill.y,
            timestamp = kill.timestamp,
            killCount = 1,
        }
    end
end

-- Returns a table of all kill records for a given map (keyed by composite key).
function Data:GetKillsForMap(mapID)
    local result = {}
    for key, kill in pairs(RMR_DB.kills) do
        if kill.mapID == mapID then
            result[key] = kill
        end
    end
    return result
end

-- Returns the raw kills table (all maps).
function Data:GetAllKills()
    return RMR_DB.kills
end

-- Total number of tracked kills.
function Data:Count()
    local n = 0
    for _ in pairs(RMR_DB.kills) do n = n + 1 end
    return n
end

-- Wipe all saved data.
function Data:ClearAll()
    wipe(RMR_DB.kills)
end
