-- RememberMyRare — Tooltip
-- Shared tooltip renderer used by both world-map and minimap pins.

local Tooltip = RMR.Tooltip

function Tooltip:Show(owner, kill)
    if not kill then return end
    GameTooltip:SetOwner(owner, "ANCHOR_RIGHT")
    GameTooltip:ClearLines()

    -- Name in rare gold colour.
    GameTooltip:AddLine(kill.name, 1, 0.82, 0)

    GameTooltip:AddLine(" ")

    -- Kill date (converted from Unix timestamp to readable date).
    local dateStr = date("%Y-%m-%d %H:%M", kill.timestamp)
    GameTooltip:AddDoubleLine("Killed:", dateStr, 1, 1, 1, 0.65, 0.65, 0.65)

    if kill.killCount > 1 then
        GameTooltip:AddDoubleLine("Kill count:", tostring(kill.killCount), 1, 1, 1, 0.65, 0.65, 0.65)
    end

    GameTooltip:Show()
end
