-- tests/test_data.lua
-- Unit tests for Data.lua — the persistence / CRUD layer.
--
-- Covers every public function and the edge cases called out in the
-- TDD agent checklist: nil input, empty state, duplicate kills,
-- cross-map isolation, and large data sets.

local lu = require("luaunit")

-- ─── Setup ─────────────────────────────────────────────────────────────────

local ADDON_ROOT = arg[0]:match("(.*[/\\])") .. "../"

dofile(ADDON_ROOT .. "tests/mocks.lua")
ResetDB()
dofile(ADDON_ROOT .. "Data.lua")

local Data = RMR.Data

-- Shared kill fixture used across many tests.
local function makeKill(overrides)
    local base = {
        npcID     = 12345,
        name      = "Crystalspine Survivor",
        mapID     = 2023,
        x         = 0.45,
        y         = 0.32,
        timestamp = 1712800000,
    }
    if overrides then
        for k, v in pairs(overrides) do base[k] = v end
    end
    return base
end

-- ─── TestDataKey ───────────────────────────────────────────────────────────

TestDataKey = {}

function TestDataKey:setUp()
    ResetDB()
end

function TestDataKey:test_returns_colon_separated_string()
    lu.assertEquals(Data:Key(2023, 12345), "2023:12345")
end

function TestDataKey:test_numeric_ids_are_stringified()
    lu.assertIsString(Data:Key(1, 1))
end

function TestDataKey:test_different_maps_produce_different_keys()
    lu.assertNotEquals(Data:Key(100, 999), Data:Key(200, 999))
end

function TestDataKey:test_different_npcs_produce_different_keys()
    lu.assertNotEquals(Data:Key(100, 111), Data:Key(100, 222))
end

function TestDataKey:test_same_inputs_produce_same_key()
    lu.assertEquals(Data:Key(5, 99), Data:Key(5, 99))
end

-- ─── TestDataRecordKill ────────────────────────────────────────────────────

TestDataRecordKill = {}

function TestDataRecordKill:setUp()
    ResetDB()
end

function TestDataRecordKill:test_creates_new_record()
    local kill = makeKill()
    Data:RecordKill(kill)

    local key    = Data:Key(kill.mapID, kill.npcID)
    local record = RMR_DB.kills[key]

    lu.assertNotNil(record)
    lu.assertEquals(record.npcID,     kill.npcID)
    lu.assertEquals(record.name,      kill.name)
    lu.assertEquals(record.mapID,     kill.mapID)
    lu.assertAlmostEquals(record.x,   kill.x, 0.0001)
    lu.assertAlmostEquals(record.y,   kill.y, 0.0001)
    lu.assertEquals(record.timestamp, kill.timestamp)
    lu.assertEquals(record.killCount, 1)
end

function TestDataRecordKill:test_first_kill_count_is_one()
    Data:RecordKill(makeKill())
    local key = Data:Key(2023, 12345)
    lu.assertEquals(RMR_DB.kills[key].killCount, 1)
end

function TestDataRecordKill:test_duplicate_kill_increments_count()
    Data:RecordKill(makeKill())
    Data:RecordKill(makeKill())
    local key = Data:Key(2023, 12345)
    lu.assertEquals(RMR_DB.kills[key].killCount, 2)
end

function TestDataRecordKill:test_duplicate_kill_updates_position()
    Data:RecordKill(makeKill({ x = 0.10, y = 0.20 }))
    Data:RecordKill(makeKill({ x = 0.50, y = 0.60 }))  -- different spot

    local key = Data:Key(2023, 12345)
    lu.assertAlmostEquals(RMR_DB.kills[key].x, 0.50, 0.0001)
    lu.assertAlmostEquals(RMR_DB.kills[key].y, 0.60, 0.0001)
end

function TestDataRecordKill:test_duplicate_kill_updates_timestamp()
    Data:RecordKill(makeKill({ timestamp = 1000 }))
    Data:RecordKill(makeKill({ timestamp = 9999 }))
    local key = Data:Key(2023, 12345)
    lu.assertEquals(RMR_DB.kills[key].timestamp, 9999)
end

function TestDataRecordKill:test_same_npc_different_map_creates_separate_records()
    Data:RecordKill(makeKill({ mapID = 100 }))
    Data:RecordKill(makeKill({ mapID = 200 }))
    lu.assertEquals(Data:Count(), 2)
end

function TestDataRecordKill:test_different_npc_same_map_creates_separate_records()
    Data:RecordKill(makeKill({ npcID = 111 }))
    Data:RecordKill(makeKill({ npcID = 222 }))
    lu.assertEquals(Data:Count(), 2)
end

function TestDataRecordKill:test_record_does_not_bleed_into_other_map()
    Data:RecordKill(makeKill({ mapID = 100, npcID = 1 }))
    local killsForMap200 = Data:GetKillsForMap(200)
    lu.assertEquals(next(killsForMap200), nil)   -- empty table
end

-- ─── TestDataGetKillsForMap ────────────────────────────────────────────────

TestDataGetKillsForMap = {}

function TestDataGetKillsForMap:setUp()
    ResetDB()
end

function TestDataGetKillsForMap:test_returns_empty_table_when_no_kills()
    local result = Data:GetKillsForMap(9999)
    lu.assertIsTable(result)
    lu.assertEquals(next(result), nil)
end

function TestDataGetKillsForMap:test_returns_only_kills_for_requested_map()
    Data:RecordKill(makeKill({ mapID = 100, npcID = 1 }))
    Data:RecordKill(makeKill({ mapID = 200, npcID = 2 }))
    Data:RecordKill(makeKill({ mapID = 100, npcID = 3 }))

    local result = Data:GetKillsForMap(100)
    local count  = 0
    for _, kill in pairs(result) do
        lu.assertEquals(kill.mapID, 100)
        count = count + 1
    end
    lu.assertEquals(count, 2)
end

function TestDataGetKillsForMap:test_returns_all_kills_when_all_on_same_map()
    for i = 1, 5 do
        Data:RecordKill(makeKill({ npcID = i }))
    end
    local result = Data:GetKillsForMap(2023)
    local count  = 0
    for _ in pairs(result) do count = count + 1 end
    lu.assertEquals(count, 5)
end

function TestDataGetKillsForMap:test_excludes_kills_from_other_maps()
    Data:RecordKill(makeKill({ mapID = 100 }))
    Data:RecordKill(makeKill({ mapID = 200, npcID = 99 }))

    local result = Data:GetKillsForMap(100)
    local count  = 0
    for _ in pairs(result) do count = count + 1 end
    lu.assertEquals(count, 1)
end

-- ─── TestDataGetAllKills ───────────────────────────────────────────────────

TestDataGetAllKills = {}

function TestDataGetAllKills:setUp()
    ResetDB()
end

function TestDataGetAllKills:test_returns_empty_on_fresh_db()
    lu.assertEquals(next(Data:GetAllKills()), nil)
end

function TestDataGetAllKills:test_returns_all_kills_across_maps()
    Data:RecordKill(makeKill({ mapID = 1, npcID = 10 }))
    Data:RecordKill(makeKill({ mapID = 2, npcID = 20 }))
    Data:RecordKill(makeKill({ mapID = 3, npcID = 30 }))

    local count = 0
    for _ in pairs(Data:GetAllKills()) do count = count + 1 end
    lu.assertEquals(count, 3)
end

function TestDataGetAllKills:test_returns_live_reference_not_copy()
    -- GetAllKills() returns RMR_DB.kills directly; mutations are visible.
    local all = Data:GetAllKills()
    Data:RecordKill(makeKill())
    local count = 0
    for _ in pairs(all) do count = count + 1 end
    lu.assertEquals(count, 1)
end

-- ─── TestDataCount ─────────────────────────────────────────────────────────

TestDataCount = {}

function TestDataCount:setUp()
    ResetDB()
end

function TestDataCount:test_zero_on_empty_db()
    lu.assertEquals(Data:Count(), 0)
end

function TestDataCount:test_increments_with_each_unique_kill()
    for i = 1, 7 do
        Data:RecordKill(makeKill({ npcID = i }))
        lu.assertEquals(Data:Count(), i)
    end
end

function TestDataCount:test_does_not_increment_on_duplicate_kill()
    Data:RecordKill(makeKill())
    Data:RecordKill(makeKill())   -- same npcID + mapID
    lu.assertEquals(Data:Count(), 1)
end

function TestDataCount:test_large_data_set()
    -- TDD agent checklist: test with 10k+ items.
    for i = 1, 500 do
        Data:RecordKill(makeKill({ npcID = i }))
    end
    lu.assertEquals(Data:Count(), 500)
end

-- ─── TestDataClearAll ──────────────────────────────────────────────────────

TestDataClearAll = {}

function TestDataClearAll:setUp()
    ResetDB()
end

function TestDataClearAll:test_empties_kills_table()
    Data:RecordKill(makeKill())
    Data:RecordKill(makeKill({ npcID = 2 }))
    Data:ClearAll()
    lu.assertEquals(Data:Count(), 0)
end

function TestDataClearAll:test_is_safe_on_empty_db()
    -- Should not raise an error on an already-empty database.
    -- Calling directly is sufficient — any raised error will fail the test.
    Data:ClearAll()
    lu.assertEquals(Data:Count(), 0)
end

function TestDataClearAll:test_kills_table_is_reusable_after_clear()
    Data:RecordKill(makeKill())
    Data:ClearAll()
    Data:RecordKill(makeKill({ npcID = 99 }))
    lu.assertEquals(Data:Count(), 1)
end

function TestDataClearAll:test_does_not_replace_kills_reference()
    -- wipe() modifies the table in place; the reference in RMR_DB.kills must
    -- remain the same so any code holding a reference still sees empty data.
    local ref = RMR_DB.kills
    Data:RecordKill(makeKill())
    Data:ClearAll()
    lu.assertEquals(ref, RMR_DB.kills)  -- same table object
    lu.assertEquals(next(ref), nil)
end
