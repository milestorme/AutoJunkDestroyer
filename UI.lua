-- File: UI.lua
-- UI namespace/wiring for AutoJunkDestroyer runtime.

local AJD = _G.AutoJunkDestroyerRuntime or {}
AJD.UI = AJD.UI or {}

function AJD.UI.TogglePopup()
    if AJD.TogglePopup then
        AJD.TogglePopup()
    end
end

function AJD.UI.ButtonCommand(arg)
    if AJD.HandleButtonCommand then
        AJD.HandleButtonCommand(arg)
    end
end
