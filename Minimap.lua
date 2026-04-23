-- RememberMyRare — Minimap
-- Renders kill pins on the minimap via HereBeDragons-Pins-2.0.
--
-- HBDPins tracks the player's position and handles showing / hiding / edge-
-- floating the icon frames automatically.  We only need to add/remove them
-- when the kill database changes.

local Minimap = RMR.Minimap

local HBDPins

local PIN_SIZE        = 14  -- slightly smaller than world-map pins
local PIN_FRAME_LEVEL = 5   -- layers above Minimap base to stay visible over blips

local NEAR_THRESHOLD = 0.08  -- ~150 yards in map-coordinate units
local ALPHA_NEAR     = 0.2
local ALPHA_FAR      = 1.0

-- ─── Pin pool ──────────────────────────────────────────────────────────────

local pool       = {}
local activePins = {}

local function CreateIconFrame()
    local f = CreateFrame("Button", nil, _G.Minimap)
    f:SetSize(PIN_SIZE, PIN_SIZE)
    f:SetFrameLevel(_G.Minimap:GetFrameLevel() + PIN_FRAME_LEVEL)

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
    HBDPins:RemoveMinimapIcon(RMR, pin)
    pin.kill = nil
    pin:Hide()
    table.insert(pool, pin)
end

-- ─── Proximity fade ────────────────────────────────────────────────────────

local proximityFrame = CreateFrame("Frame")
local proximityElapsed = 0
proximityFrame:SetScript("OnUpdate", function(_, dt)
    proximityElapsed = proximityElapsed + dt
    if proximityElapsed < 1 then return end
    proximityElapsed = 0

    local mapID = C_Map.GetBestMapForUnit("player")
    if not mapID then return end
    local pos = C_Map.GetPlayerMapPosition(mapID, "player")
    if not pos then return end

    for _, pin in ipairs(activePins) do
        if pin.kill.mapID == mapID then
            local dx = pos.x - pin.kill.x
            local dy = pos.y - pin.kill.y
            local dist = math.sqrt(dx * dx + dy * dy)
            pin:SetAlpha(dist < NEAR_THRESHOLD and ALPHA_NEAR or ALPHA_FAR)
        else
            pin:SetAlpha(ALPHA_FAR)
        end
    end
end)

-- ─── Public API ────────────────────────────────────────────────────────────

-- Adds a pin for a single kill without rebuilding the entire set.
function Minimap:AddPin(kill)
    if RMR_DB.hidden then return end
    local pin = AcquirePin()
    pin.kill  = kill
    HBDPins:AddMinimapIconMap(
        RMR, pin,
        kill.mapID, kill.x, kill.y,
        false,  -- showInParentZone
        true    -- floatOnEdge
    )
    table.insert(activePins, pin)
end

-- Full rebuild — called on addon load or after ClearAll.
function Minimap:Refresh()
    for _, pin in ipairs(activePins) do
        ReleasePin(pin)
    end
    wipe(activePins)

    if RMR_DB.hidden then return end

    for _, kill in pairs(RMR_DB.kills) do
        local pin = AcquirePin()
        pin.kill  = kill

        -- showInParentZone = false : only show pin when in the exact zone
        -- floatOnEdge      = true  : pin drifts to minimap edge when out of range
        HBDPins:AddMinimapIconMap(
            RMR, pin,
            kill.mapID, kill.x, kill.y,
            false,  -- showInParentZone
            true    -- floatOnEdge
        )

        table.insert(activePins, pin)
    end
end

function Minimap:Init()
    HBDPins = LibStub("HereBeDragons-Pins-2.0")
    self:Refresh()
end
