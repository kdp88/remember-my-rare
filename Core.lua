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
    hidden  = false,
}

local initFrame = CreateFrame("Frame")
initFrame:RegisterEvent("ADDON_LOADED")
initFrame:RegisterEvent("PLAYER_LOGIN")
initFrame:SetScript("OnEvent", function(self, event, addonName)
    if event == "ADDON_LOADED" then
        if addonName ~= "RememberMyRare" then return end

        -- Initialise or migrate SavedVariables (safe to do here — no frame ops)
        if type(RMR_DB) ~= "table" then
            RMR_DB = CopyTable(DB_DEFAULTS)
        end
        if not RMR_DB.kills then
            RMR_DB.kills = {}
        end
        if RMR_DB.hidden == nil then
            RMR_DB.hidden = false
        end

        RMR.Data:Init()

    elseif event == "PLAYER_LOGIN" then

        -- Frame operations deferred to PLAYER_LOGIN — safe execution context in WoW 12.0
        RMR.Events:Init()
        RMR.WorldMap:Init()
        RMR.Minimap:Init()
        RMR.Config:Init()

        print("|cFF00FF00RememberMyRare|r loaded — " .. RMR.Data:Count() .. " rare kills tracked.")
    end
end)
