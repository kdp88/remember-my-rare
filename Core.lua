-- RememberMyRare — Core
-- Namespace bootstrap and SavedVariables initialisation.

RMR = {}
RMR.VERSION     = "1.0.0"
RMR.PIN_TEXTURE = "Interface\\Icons\\INV_Misc_Bone_HumanSkull_01"

-- Module tables populated by each file on load
RMR.Data     = {}
RMR.Events   = {}
RMR.WorldMap = {}
RMR.Minimap  = {}
RMR.Tooltip  = {}
RMR.Config   = {}

local DB_DEFAULTS = {
    version = 1,
    kills   = {},
}

local initFrame = CreateFrame("Frame")
initFrame:RegisterEvent("ADDON_LOADED")
initFrame:SetScript("OnEvent", function(self, event, addonName)
    if addonName ~= "RememberMyRare" then return end
    self:UnregisterEvent("ADDON_LOADED")

    -- Initialise or migrate SavedVariables
    if type(RMR_DB) ~= "table" then
        RMR_DB = CopyTable(DB_DEFAULTS)
    end
    if not RMR_DB.kills then
        RMR_DB.kills = {}
    end

    RMR.Data:Init()
    RMR.Events:Init()
    RMR.WorldMap:Init()
    RMR.Minimap:Init()
    RMR.Config:Init()

    print("|cFF00FF00RememberMyRare|r loaded — " .. RMR.Data:Count() .. " rare kills tracked.")
end)
