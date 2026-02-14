-- File: Commands.lua
-- Slash command router module

local AJD = _G.AutoJunkDestroyerRuntime or {}

SLASH_AUTOJUNKDESTROYER1 = "/ajd"
SlashCmdList.AUTOJUNKDESTROYER = function(msg)
    msg = (msg or ""):lower()

    if msg == "pause" then
        (AJD.Core and AJD.Core.TogglePause and AJD.Core.TogglePause() or AJD.TogglePause())
        return
    end

    if msg == "resume" then
        (AJD.Core and AJD.Core.Resume and AJD.Core.Resume() or AJD.Resume())
        return
    end

    if msg == "status" then
        (AJD.Core and AJD.Core.PrintStatus and AJD.Core.PrintStatus() or AJD.PrintStatus())
        return
    end

    if msg:match("^threshold") then
        local arg = msg:match("^threshold%s*(.*)$") or ""
        AJD.SetThreshold(arg)
        return
    end

    if msg:match("^button") then
        local arg = (msg:match("^button%s*(.*)$") or ""):lower()
        (AJD.UI and AJD.UI.ButtonCommand and AJD.UI.ButtonCommand(arg) or AJD.HandleButtonCommand(arg))
        return
    end

    if msg:match("^minimap") then
        local arg = (msg:match("^minimap%s*(.*)$") or ""):lower()
        (AJD.Minimap and AJD.Minimap.Command and AJD.Minimap.Command(arg) or AJD.HandleMinimapCommand(arg))
        return
    end

    if msg == "toggle" then
        (AJD.UI and AJD.UI.TogglePopup and AJD.UI.TogglePopup() or AJD.TogglePopup())
        return
    end

    AJD.PrintHelp()
end
