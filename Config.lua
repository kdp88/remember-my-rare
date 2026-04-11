-- RememberMyRare — Config
-- Slash-command interface: /rmr

local Config = RMR.Config

local function PrintHelp()
    print("|cFF00FF00RememberMyRare|r commands:")
    print("  |cFFFFFF00/rmr|r            — show status (kill count)")
    print("  |cFFFFFF00/rmr list|r       — list all tracked kills")
    print("  |cFFFFFF00/rmr clear|r      — wipe all saved kills (asks for confirmation)")
    print("  |cFFFFFF00/rmr confirm|r    — confirm a pending /rmr clear")
end

local clearPending = false

local function HandleCommand(input)
    local cmd = strtrim(input or ""):lower()

    if cmd == "" then
        print("|cFF00FF00RememberMyRare|r: " .. RMR.Data:Count() .. " rare kill(s) tracked.")

    elseif cmd == "list" then
        clearPending = false
        local kills = RMR.Data:GetAllKills()
        local count = 0
        for _, kill in pairs(kills) do
            count = count + 1
            local dateStr = date("%Y-%m-%d", kill.timestamp)
            print(string.format("  [%s] %s (map %d, kills: %d)",
                dateStr, kill.name, kill.mapID, kill.killCount))
        end
        if count == 0 then
            print("|cFF00FF00RememberMyRare|r: No kills recorded yet.")
        end

    elseif cmd == "clear" then
        if RMR.Data:Count() == 0 then
            print("|cFF00FF00RememberMyRare|r: Nothing to clear.")
        else
            clearPending = true
            print("|cFFFF4444RememberMyRare|r: This will delete all " ..
                RMR.Data:Count() .. " kill records.")
            print("Type |cFFFFFF00/rmr confirm|r to proceed, or anything else to cancel.")
        end

    elseif cmd == "confirm" then
        if clearPending then
            RMR.Data:ClearAll()
            RMR.WorldMap:Refresh()
            RMR.Minimap:Refresh()
            clearPending = false
            print("|cFF00FF00RememberMyRare|r: All kills cleared.")
        else
            print("|cFF00FF00RememberMyRare|r: Nothing to confirm. Use /rmr clear first.")
        end

    else
        clearPending = false
        PrintHelp()
    end
end

function Config:Init()
    SLASH_REMEMBERMYRARE1 = "/rmr"
    SlashCmdList["REMEMBERMYRARE"] = HandleCommand
end
