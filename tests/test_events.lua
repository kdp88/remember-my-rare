-- tests/test_events.lua
-- Integration tests for Events.lua — kill detection via the two-event pattern.
--
-- Strategy: load Events.lua, call Events:Init() to install the event frame,
-- then drive it by setting global stubs and calling frame:FireEvent().
-- We observe outcomes through RMR.Data (i.e. whether a kill was recorded).

local lu = require("luaunit")

local ADDON_ROOT = arg[0]:match("(.*[/\\])") .. "../"

dofile(ADDON_ROOT .. "tests/mocks.lua")
ResetDB()
dofile(ADDON_ROOT .. "Data.lua")   -- required by Events.lua
dofile(ADDON_ROOT .. "Events.lua")

-- ─── Test infrastructure ───────────────────────────────────────────────────

-- Capture the event frame that Events:Init() creates so tests can fire events.
local _originalCreateFrame = CreateFrame
local capturedFrame

CreateFrame = function(...)
    capturedFrame = _originalCreateFrame(...)
    return capturedFrame
end

-- Stub out the map refresh calls so Events.lua doesn't crash when
-- WorldMap/Minimap modules are not loaded.
RMR.WorldMap.Refresh = function() end
RMR.WorldMap.AddPin  = function() end
RMR.Minimap.Refresh  = function() end
RMR.Minimap.AddPin   = function() end

-- Suppress in-game chat output during tests.
local printedMessages = {}
print = function(msg) table.insert(printedMessages, msg) end

-- ─── Helpers ───────────────────────────────────────────────────────────────

local RARE_GUID    = "Creature-0-3858-0-54-187709-000049CFB2"
local RARE_NPC_ID  = 187709
local TEST_MAP_ID  = 2023
local TEST_POS     = { x = 0.45, y = 0.32 }   -- mock vector2 object

local function setupRareTarget(guid, classification)
    guid           = guid or RARE_GUID
    classification = classification or "rare"
    UnitGUID           = function(unit) return unit == "target" and guid or nil end
    UnitClassification = function(unit) return unit == "target" and classification or "normal" end
    UnitName           = function(unit) return unit == "target" and "Test Rare" or nil end
    C_Map.GetBestMapForUnit    = function() return TEST_MAP_ID end
    C_Map.GetPlayerMapPosition = function() return TEST_POS end
end

local function fireTargetChanged()
    capturedFrame:FireEvent("PLAYER_TARGET_CHANGED")
end

local function fireUnitDied(guid)
    guid = guid or RARE_GUID
    capturedFrame:FireEvent("UNIT_DIED", guid)
end

local function fireEnteringWorld()
    capturedFrame:FireEvent("PLAYER_ENTERING_WORLD")
end

-- ─── Module init ───────────────────────────────────────────────────────────

TestEventsInit = {}

function TestEventsInit:setUp()
    ResetDB()
    printedMessages = {}
    print = function(msg) table.insert(printedMessages, msg) end
    capturedFrame   = nil
    -- Reinstall the frame-capture wrapper so dofile(Events.lua) populates capturedFrame.
    local _orig = CreateFrame
    CreateFrame = function(...) capturedFrame = _orig(...); return capturedFrame end
    RMR.Events = {}
    dofile(ADDON_ROOT .. "Events.lua")
    CreateFrame = _orig
    RMR.WorldMap.Refresh = function() end
    RMR.WorldMap.AddPin  = function() end
    RMR.Minimap.Refresh  = function() end
    RMR.Minimap.AddPin   = function() end
    RMR.Events:Init()
end

function TestEventsInit:test_init_creates_event_frame()
    lu.assertNotNil(capturedFrame)
end

-- ─── TestKillDetection ─────────────────────────────────────────────────────

TestKillDetection = {}

function TestKillDetection:setUp()
    ResetDB()
    printedMessages = {}
    print = function(msg) table.insert(printedMessages, msg) end
    capturedFrame   = nil
    local _orig = CreateFrame
    CreateFrame = function(...) capturedFrame = _orig(...); return capturedFrame end
    RMR.Events = {}
    dofile(ADDON_ROOT .. "Events.lua")
    CreateFrame = _orig
    RMR.WorldMap.Refresh = function() end
    RMR.WorldMap.AddPin  = function() end
    RMR.Minimap.Refresh  = function() end
    RMR.Minimap.AddPin   = function() end
    RMR.Events:Init()
    -- Default target is no target.
    UnitGUID           = function() return nil end
    UnitClassification = function() return "normal" end
end

-- Happy path ----------------------------------------------------------------

function TestKillDetection:test_rare_kill_is_recorded()
    setupRareTarget()
    fireTargetChanged()
    fireUnitDied()
    lu.assertEquals(RMR.Data:Count(), 1)
end

function TestKillDetection:test_rareelite_kill_is_recorded()
    setupRareTarget(RARE_GUID, "rareelite")
    fireTargetChanged()
    fireUnitDied()
    lu.assertEquals(RMR.Data:Count(), 1)
end

function TestKillDetection:test_recorded_kill_has_correct_npc_id()
    setupRareTarget()
    fireTargetChanged()
    fireUnitDied()
    local kills = RMR.Data:GetAllKills()
    local record = kills[RMR.Data:Key(TEST_MAP_ID, RARE_NPC_ID)]
    lu.assertNotNil(record)
    lu.assertEquals(record.npcID, RARE_NPC_ID)
end

function TestKillDetection:test_recorded_kill_has_correct_map_id()
    setupRareTarget()
    fireTargetChanged()
    fireUnitDied()
    local record = RMR.Data:GetAllKills()[RMR.Data:Key(TEST_MAP_ID, RARE_NPC_ID)]
    lu.assertEquals(record.mapID, TEST_MAP_ID)
end

function TestKillDetection:test_recorded_kill_has_correct_position()
    setupRareTarget()
    fireTargetChanged()
    fireUnitDied()
    local record = RMR.Data:GetAllKills()[RMR.Data:Key(TEST_MAP_ID, RARE_NPC_ID)]
    lu.assertAlmostEquals(record.x, TEST_POS.x, 0.0001)
    lu.assertAlmostEquals(record.y, TEST_POS.y, 0.0001)
end

function TestKillDetection:test_recorded_kill_has_timestamp()
    setupRareTarget()
    fireTargetChanged()
    fireUnitDied()
    local record = RMR.Data:GetAllKills()[RMR.Data:Key(TEST_MAP_ID, RARE_NPC_ID)]
    lu.assertIsNumber(record.timestamp)
    lu.assertTrue(record.timestamp > 0)
end

function TestKillDetection:test_confirmation_message_printed()
    setupRareTarget()
    fireTargetChanged()
    fireUnitDied()
    lu.assertTrue(#printedMessages > 0)
    lu.assertStrContains(printedMessages[#printedMessages], "Test Rare")
end

function TestKillDetection:test_map_pin_added_after_kill()
    local pinAdded = false
    RMR.WorldMap.AddPin = function() pinAdded = true end
    setupRareTarget()
    fireTargetChanged()
    fireUnitDied()
    lu.assertTrue(pinAdded)
end

function TestKillDetection:test_minimap_pin_added_after_kill()
    local pinAdded = false
    RMR.Minimap.AddPin = function() pinAdded = true end
    setupRareTarget()
    fireTargetChanged()
    fireUnitDied()
    lu.assertTrue(pinAdded)
end

-- Negative / guard cases ----------------------------------------------------

function TestKillDetection:test_normal_mob_kill_is_not_recorded()
    -- Normal classification — should be ignored entirely.
    UnitGUID           = function() return RARE_GUID end
    UnitClassification = function() return "normal" end
    C_Map.GetBestMapForUnit    = function() return TEST_MAP_ID end
    C_Map.GetPlayerMapPosition = function() return TEST_POS end

    fireTargetChanged()
    fireUnitDied()
    lu.assertEquals(RMR.Data:Count(), 0)
end

function TestKillDetection:test_elite_mob_kill_is_not_recorded()
    UnitGUID           = function() return RARE_GUID end
    UnitClassification = function() return "elite" end
    C_Map.GetBestMapForUnit    = function() return TEST_MAP_ID end
    C_Map.GetPlayerMapPosition = function() return TEST_POS end

    fireTargetChanged()
    fireUnitDied()
    lu.assertEquals(RMR.Data:Count(), 0)
end

function TestKillDetection:test_unit_died_without_prior_target_is_ignored()
    -- Fire UNIT_DIED for a GUID we never targeted.
    fireUnitDied("Creature-0-1-2-3-99999-AABBCCDD")
    lu.assertEquals(RMR.Data:Count(), 0)
end

function TestKillDetection:test_target_changed_to_nil_does_not_error()
    UnitGUID = function() return nil end
    -- Calling directly is sufficient — any raised error will fail the test.
    fireTargetChanged()
    lu.assertEquals(RMR.Data:Count(), 0)
end

function TestKillDetection:test_target_changed_no_map_does_not_record()
    -- If GetBestMapForUnit returns nil (e.g. loading screen) nothing is saved.
    UnitGUID           = function() return RARE_GUID end
    UnitClassification = function() return "rare" end
    C_Map.GetBestMapForUnit    = function() return nil end
    C_Map.GetPlayerMapPosition = function() return TEST_POS end

    fireTargetChanged()
    fireUnitDied()
    lu.assertEquals(RMR.Data:Count(), 0)
end

function TestKillDetection:test_target_changed_no_position_does_not_record()
    UnitGUID           = function() return RARE_GUID end
    UnitClassification = function() return "rare" end
    C_Map.GetBestMapForUnit    = function() return TEST_MAP_ID end
    C_Map.GetPlayerMapPosition = function() return nil end  -- position unavailable

    fireTargetChanged()
    fireUnitDied()
    lu.assertEquals(RMR.Data:Count(), 0)
end

function TestKillDetection:test_non_creature_guid_does_not_record()
    -- Player or pet GUIDs should be ignored.
    local playerGUID = "Player-0-3858-0-54-187709-000049CFB2"
    UnitGUID           = function() return playerGUID end
    UnitClassification = function() return "rare" end
    C_Map.GetBestMapForUnit    = function() return TEST_MAP_ID end
    C_Map.GetPlayerMapPosition = function() return TEST_POS end

    fireTargetChanged()
    fireUnitDied(playerGUID)
    lu.assertEquals(RMR.Data:Count(), 0)
end

function TestKillDetection:test_different_unit_died_guid_does_not_record()
    -- We targeted the rare but a different unit died.
    setupRareTarget()
    fireTargetChanged()
    fireUnitDied("Creature-0-1-2-3-00001-FFFFFF")  -- different GUID
    lu.assertEquals(RMR.Data:Count(), 0)
end

-- Session boundary ----------------------------------------------------------

function TestKillDetection:test_entering_world_clears_pending_rares()
    -- Target a rare, enter a new zone (loading screen), then the UNIT_DIED
    -- fires after the zone transition — should NOT be recorded.
    setupRareTarget()
    fireTargetChanged()

    fireEnteringWorld()   -- zone change / loading screen

    fireUnitDied()        -- late UNIT_DIED from previous zone
    lu.assertEquals(RMR.Data:Count(), 0)
end

-- Cross-session persistence (unit-level) ------------------------------------

function TestKillDetection:test_second_kill_increments_kill_count()
    setupRareTarget()
    fireTargetChanged()
    fireUnitDied()
    fireTargetChanged()
    fireUnitDied()
    local record = RMR.Data:GetAllKills()[RMR.Data:Key(TEST_MAP_ID, RARE_NPC_ID)]
    lu.assertEquals(record.killCount, 2)
end

-- ─── TestGuidParsing ───────────────────────────────────────────────────────
-- Tests strsplit-based NPC ID extraction via observable behaviour
-- (record the kill, check the stored npcID).

TestGuidParsing = {}

function TestGuidParsing:setUp()
    ResetDB()
    printedMessages = {}
    print = function(msg) table.insert(printedMessages, msg) end
    capturedFrame = nil
    local _orig = CreateFrame
    CreateFrame = function(...) capturedFrame = _orig(...); return capturedFrame end
    RMR.Events = {}
    dofile(ADDON_ROOT .. "Events.lua")
    CreateFrame = _orig
    RMR.WorldMap.Refresh = function() end
    RMR.WorldMap.AddPin  = function() end
    RMR.Minimap.Refresh  = function() end
    RMR.Minimap.AddPin   = function() end
    RMR.Events:Init()
end

local function killWithGUID(guid, npcID)
    UnitGUID           = function(u) return u == "target" and guid or nil end
    UnitClassification = function()  return "rare" end
    UnitName           = function()  return "Rare" end
    C_Map.GetBestMapForUnit    = function() return TEST_MAP_ID end
    C_Map.GetPlayerMapPosition = function() return TEST_POS end
    capturedFrame:FireEvent("PLAYER_TARGET_CHANGED")
    capturedFrame:FireEvent("UNIT_DIED", guid)
end

function TestGuidParsing:test_standard_creature_guid_parsed_correctly()
    killWithGUID("Creature-0-3858-0-54-187709-000049CFB2", 187709)
    local record = RMR.Data:GetAllKills()[RMR.Data:Key(TEST_MAP_ID, 187709)]
    lu.assertNotNil(record)
    lu.assertEquals(record.npcID, 187709)
end

function TestGuidParsing:test_different_npc_id_in_guid()
    killWithGUID("Creature-0-3858-0-54-55847-000049CFB2", 55847)
    local record = RMR.Data:GetAllKills()[RMR.Data:Key(TEST_MAP_ID, 55847)]
    lu.assertNotNil(record)
    lu.assertEquals(record.npcID, 55847)
end

function TestGuidParsing:test_vehicle_guid_type_not_recorded()
    -- "Vehicle" prefix — ExtractNPCID should return nil.
    killWithGUID("Vehicle-0-3858-0-54-99999-000049CFB2", 99999)
    lu.assertEquals(RMR.Data:Count(), 0)
end
