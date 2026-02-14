-- File: Minimap.lua
-- Minimap namespace/wiring for AutoJunkDestroyer runtime.

local AJD = _G.AutoJunkDestroyerRuntime or {}
AJD.Minimap = AJD.Minimap or {}

function AJD.Minimap.Command(arg)
    if AJD.HandleMinimapCommand then
        AJD.HandleMinimapCommand(arg)
    end
end
