-- RememberMyRare — WorldMap
-- Renders kill pins on the world map via HereBeDragons-Pins-2.0.
--
-- HBDPins owns positioning: we create and pool the icon frames, set their
-- textures and tooltip scripts, then hand them to HBDPins which parents them
-- inside its own MapCanvas pin frames whenever the matching zone is open.

local WorldMap = RMR.WorldMap

local HBDPins

local PIN_SIZE = 16

-- ─── Pin pool ──────────────────────────────────────────────────────────────

local pool       = {}   -- recycled icon frames
local activePins = {}   -- currently live icons

local function CreateIconFrame()
    local f = CreateFrame("Button", nil, UIParent)
    f:SetSize(PIN_SIZE, PIN_SIZE)

    local tex = f:CreateTexture(nil, "OVERLAY")
    tex:SetAllPoints()
    tex:SetTexture(RMR.PIN_TEXTURE)
    f.tex = tex

    f:SetScript("OnEnter", function(self)
        RMR.Tooltip:Show(self, self.kill)
    end)
    f:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)

    return f
end

local function AcquirePin()
    local pin = table.remove(pool) or CreateIconFrame()
    pin:Show()
    return pin
end

local function ReleasePin(pin)
    HBDPins:RemoveWorldMapIcon(RMR, pin)
    pin.kill = nil
    pin:Hide()
    pin:SetParent(UIParent)
    pin:ClearAllPoints()
    table.insert(pool, pin)
end

-- ─── Public API ────────────────────────────────────────────────────────────

-- Adds a pin for a single kill without rebuilding the entire set.
-- Use this after recording a new kill to avoid O(n) teardown/rebuild.
function WorldMap:AddPin(kill)
    if RMR_DB.hidden then return end
    local pin = AcquirePin()
    pin.kill  = kill
    HBDPins:AddWorldMapIconMap(
        RMR, pin,
        kill.mapID, kill.x, kill.y,
        HBD_PINS_WORLDMAP_SHOW_CONTINENT
    )
    table.insert(activePins, pin)
end

-- Full rebuild — called on addon load or after ClearAll.
function WorldMap:Refresh()
    for _, pin in ipairs(activePins) do
        ReleasePin(pin)
    end
    wipe(activePins)

    if RMR_DB.hidden then return end

    for _, kill in pairs(RMR_DB.kills) do
        local pin = AcquirePin()
        pin.kill  = kill

        -- HBD_PINS_WORLDMAP_SHOW_CONTINENT (2): pin is visible on the zone map
        -- AND on the continent map above it, so the player can see at a glance
        -- which continent they killed rares on.
        HBDPins:AddWorldMapIconMap(
            RMR, pin,
            kill.mapID, kill.x, kill.y,
            HBD_PINS_WORLDMAP_SHOW_CONTINENT
        )

        table.insert(activePins, pin)
    end
end

function WorldMap:Init()
    HBDPins = LibStub("HereBeDragons-Pins-2.0")
    self:Refresh()
end
