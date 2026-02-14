-- File: Commands.lua
-- Slash command router module with localized aliases.

local AJD = _G.AutoJunkDestroyerRuntime or {}
local L = AJD.L or {}

local function asciiLower(s)
    if type(s) ~= "string" then return s end
    return (s:gsub("%u", function(c) return string.char(string.byte(c) + 32) end))
end

local function buildAliasMap(raw)
    local map = {}
    if type(raw) ~= "string" then
        return map
    end
    for part in raw:gmatch("[^,]+") do
        local alias = part:match("^%s*(.-)%s*$")
        if alias and alias ~= "" then
            -- Keep exact alias and ASCII-lower variant.
            -- This avoids UTF-8 corruption risks from string.lower on non-ASCII characters.
            map[alias] = true
            map[asciiLower(alias)] = true
        end
    end
    return map
end

local ALIAS = {
    pause = buildAliasMap(L["CMD_ALIAS_PAUSE"] or "pause"),
    resume = buildAliasMap(L["CMD_ALIAS_RESUME"] or "resume"),
    status = buildAliasMap(L["CMD_ALIAS_STATUS"] or "status"),
    toggle = buildAliasMap(L["CMD_ALIAS_TOGGLE"] or "toggle"),
    threshold = buildAliasMap(L["CMD_ALIAS_THRESHOLD"] or "threshold"),
    button = buildAliasMap(L["CMD_ALIAS_BUTTON"] or "button"),
    minimap = buildAliasMap(L["CMD_ALIAS_MINIMAP"] or "minimap"),
    mm_hide = buildAliasMap(L["CMD_ALIAS_MINIMAP_HIDE"] or "hide"),
    mm_show = buildAliasMap(L["CMD_ALIAS_MINIMAP_SHOW"] or "show"),
    mm_lock = buildAliasMap(L["CMD_ALIAS_MINIMAP_LOCK"] or "lock"),
    mm_unlock = buildAliasMap(L["CMD_ALIAS_MINIMAP_UNLOCK"] or "unlock"),
    mm_reset = buildAliasMap(L["CMD_ALIAS_MINIMAP_RESET"] or "reset"),
    mm_pos = buildAliasMap(L["CMD_ALIAS_MINIMAP_POS"] or "pos"),
}

local function isAlias(kind, token)
    if not token then return false end
    local set = ALIAS[kind]
    return set and (set[token] or set[asciiLower(token)])
end

SLASH_AUTOJUNKDESTROYER1 = "/ajd"
SlashCmdList.AUTOJUNKDESTROYER = function(msg)
    msg = (msg or "")

    local cmd, rest = msg:match("^(%S+)%s*(.*)$")
    if not cmd then
        AJD.PrintHelp()
        return
    end

    if isAlias("pause", cmd) then
        (AJD.Core and AJD.Core.TogglePause and AJD.Core.TogglePause() or AJD.TogglePause())
        return
    end

    if isAlias("resume", cmd) then
        (AJD.Core and AJD.Core.Resume and AJD.Core.Resume() or AJD.Resume())
        return
    end

    if isAlias("status", cmd) then
        (AJD.Core and AJD.Core.PrintStatus and AJD.Core.PrintStatus() or AJD.PrintStatus())
        return
    end

    if isAlias("threshold", cmd) then
        AJD.SetThreshold(rest or "")
        return
    end

    if isAlias("button", cmd) then
        local arg = asciiLower(rest or "")
        (AJD.UI and AJD.UI.ButtonCommand and AJD.UI.ButtonCommand(arg) or AJD.HandleButtonCommand(arg))
        return
    end

    if isAlias("minimap", cmd) then
        local mm = (rest or ""):match("^(%S+)")
        local normalized = asciiLower(rest or "")
        if mm and mm ~= "" then
            local token = mm
            if isAlias("mm_hide", token) then normalized = "hide"
            elseif isAlias("mm_show", token) then normalized = "show"
            elseif isAlias("mm_lock", token) then normalized = "lock"
            elseif isAlias("mm_unlock", token) then normalized = "unlock"
            elseif isAlias("mm_reset", token) then normalized = "reset"
            elseif isAlias("mm_pos", token) then normalized = "pos"
            end
        end
        (AJD.Minimap and AJD.Minimap.Command and AJD.Minimap.Command(normalized) or AJD.HandleMinimapCommand(normalized))
        return
    end

    if isAlias("toggle", cmd) then
        (AJD.UI and AJD.UI.TogglePopup and AJD.UI.TogglePopup() or AJD.TogglePopup())
        return
    end

    AJD.PrintHelp()
end
