-- File: Core.lua
-- Core namespace/wiring for AutoJunkDestroyer runtime.

local AJD = _G.AutoJunkDestroyerRuntime or {}
AJD.Core = AJD.Core or {}

function AJD.Core.IsDisabledNow()
    return AJD.IsDisabledNow and AJD.IsDisabledNow() or false
end

function AJD.Core.TogglePause()
    if AJD.TogglePause then
        AJD.TogglePause()
    end
end

function AJD.Core.Resume()
    if AJD.Resume then
        AJD.Resume()
    end
end

function AJD.Core.PrintStatus()
    if AJD.PrintStatus then
        AJD.PrintStatus()
    end
end
