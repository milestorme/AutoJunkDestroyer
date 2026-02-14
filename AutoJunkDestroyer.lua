-- File: AutoJunkDestroyer.lua
-- Name: Auto Junk Destroyer
-- Author: Milestorme
-- Description: Destroy junk items when bags are full easily
-- Safe, BG-aware, works with any number of bags
-- Version: 1.2.0
-------------------------------------------------
-- FUNCTION INDEX
-------------------------------------------------
-- Utility
--   Print(msg)                       -> Standardized chat output
--   IsInBattleground()               -> Returns true if player is in a BG
--   InCombat()                       -> Safe combat state detection

-- Grey Item Handling
--   GetGreyItems()                   -> Returns table of all grey-quality items
--   GetBagUsage()                    -> Returns used/free/total bag slots + percent used
--   BagsAtOrAboveThreshold()         -> True if bag usage >= configured threshold

-- Popup Button Management
--   SetButtonCount(count)            -> Updates button text with item count
--   UpdateButtonText()               -> Refreshes displayed count
--   UpdateButtonVisibility(auto)     -> Shows/hides button based on state
--   SavePopupButtonPosition()        -> Saves button screen position
--   ApplyPopupButtonPosition()       -> Restores saved button position
--   ResetPopupButtonPosition()       -> Clears saved button position

-- Battleground & Combat Handling
--   EnableAddonNow()                 -> Re-enables addon after BG/combat
--   DelayedEnableAfterBG()           -> Safe delayed re-enable after BG exit
--   SetBattlegroundState(isInBG)     -> Central BG state manager
--   OnEnterCombat()                  -> Combat entry handler
--   OnLeaveCombat()                  -> Combat exit handler

-- Deletion Logic
--   (Button OnClick)                 -> Deletes one grey item safely per click

-- Minimap / LibDataBroker
--   InitAceDB()                      -> Initializes AceDB + LibDBIcon
--   LDB.OnClick()                    -> Minimap click handler
--   LDB.OnTooltipShow()              -> Minimap tooltip text

-- Slash Commands
--   /ajd pause                       -> Toggle pause
--   /ajd resume                      -> Explicitly resume addon
--   /ajd status                      -> Show current addon status
--   /ajd toggle                      -> Toggle popup visibility
--   /ajd button [reset]              -> Show/reset popup position
--   /ajd minimap [show|hide|lock|unlock|reset|pos]

-- Event Handling
--   PLAYER_LOGIN                     -> Initialization
--   PLAYER_ENTERING_WORLD            -> BG state detection
--   PLAYER_REGEN_DISABLED            -> Combat start
--   PLAYER_REGEN_ENABLED             -> Combat end
--   BAG_UPDATE_DELAYED               -> Bag change handling
--   PLAYER_LOGOUT                    -> Persist saved data
-------------------------------------------------

local ADDON_NAME = ...
local frame = CreateFrame("Frame")
local AJD = _G.AutoJunkDestroyerRuntime or {}
_G.AutoJunkDestroyerRuntime = AJD

-- Localization (AceLocale-3.0)
local _AceLocale = LibStub and LibStub("AceLocale-3.0", true)
local L
if _AceLocale then
    L = _AceLocale:GetLocale("AutoJunkDestroyer", true)
end
if not L then
    L = setmetatable({}, { __index = function(t, k) return k end })
end


-- userPaused = what the player chose via /ajd pause
-- paused = effective pause state (userPaused OR inBattleground)
local userPaused = false
local paused = false
local inBattleground = false

local booting = true  -- true during reload/zone transitions; prevents early auto-pop
local bagRefreshPending = false
-- Delay after leaving battleground to avoid UI errors during zoning
local BG_EXIT_DELAY = 0.5

-- If we leave a BG while in combat, we defer enabling until combat ends.
local pendingEnableAfterCombat = false
local warnedWaitingForCombat = false
local DEBUG = false

-------------------------------------------------
-- Utility
-------------------------------------------------
local function Print(msg)
    -- notes: Unified chat output helper for consistent addon prefix formatting.
    DEFAULT_CHAT_FRAME:AddMessage(L["CFF00FF00_DC869E"] .. L["ADDON_NAME"] .. L["R_7FC9D5"] .. msg)
end

local function DebugPrint(msg)
    if DEBUG then
        Print("[debug] " .. tostring(msg))
    end
end

local function IsInBattleground()
    -- notes: Returns true when the player is in a PvP instance (battleground).
    local instanceType = select(2, IsInInstance())
    return instanceType == "pvp"
end

local function InCombat()
    -- notes: Returns true if the player is in combat; uses InCombatLockdown if available, with fallback.
    return (InCombatLockdown and InCombatLockdown()) or UnitAffectingCombat("player")
end

-------------------------------------------------
-- Grey Item Scan
-------------------------------------------------
local function GetGreyItems()
    -- notes: Scans all bags (0..NUM_BAG_SLOTS) and returns a list of grey (quality=0) items that have value.
    -- notes: Each entry is { bag = <bagID>, slot = <slotID> }.
    local queue = {}
    for bag = 0, NUM_BAG_SLOTS do
        local slots = C_Container.GetContainerNumSlots(bag)
        if slots and slots > 0 then
            for slot = 1, slots do
                local info = C_Container.GetContainerItemInfo(bag, slot)
                if info and info.quality == 0 and not info.hasNoValue then
                    table.insert(queue, { bag = bag, slot = slot })
                end
            end
        end
    end
    return queue
end

-- Bag capacity tracking
-- Show the delete button once bags reach this usage percentage (e.g. 0.90 = 90% full)
local DEFAULT_BAG_USAGE_THRESHOLD = 0.90

-- Soul Shard support (Warlock)

-------------------------------------------------
-- SavedVariables / Settings
-------------------------------------------------
local function EnsureSV()
    AutoJunkDestroyerDB = AutoJunkDestroyerDB or {}
    AutoJunkDestroyerDB.settings = AutoJunkDestroyerDB.settings or {}

    if AutoJunkDestroyerDB.settings.bagUsageThreshold == nil then
        AutoJunkDestroyerDB.settings.bagUsageThreshold = DEFAULT_BAG_USAGE_THRESHOLD
    end

    -- Clamp to sane range
    local t = tonumber(AutoJunkDestroyerDB.settings.bagUsageThreshold) or DEFAULT_BAG_USAGE_THRESHOLD
    if t > 1 then t = t / 100 end
    if t < 0.50 then t = 0.50 end
    if t > 0.99 then t = 0.99 end
    AutoJunkDestroyerDB.settings.bagUsageThreshold = t
    AutoJunkDestroyerDB.settings.shardButtonPos = AutoJunkDestroyerDB.settings.shardButtonPos
        or { point = "CENTER", x = 0, y = 0 }
    AutoJunkDestroyerDB.settings.shardButtonVisible = (AutoJunkDestroyerDB.settings.shardButtonVisible ~= false)
end


local function GetBagUsageThreshold()
    EnsureSV()
    local t = AutoJunkDestroyerDB.settings and AutoJunkDestroyerDB.settings.bagUsageThreshold
    if type(t) ~= "number" then
        return DEFAULT_BAG_USAGE_THRESHOLD
    end
    if t < 0.50 then t = 0.50 end
    if t > 0.99 then t = 0.99 end
    return t
end

local function GetBagUsage()
    -- notes: Computes aggregate bag usage across all player bags.
    -- notes: Returns usedSlots, freeSlots, totalSlots, percentUsed.
    local totalSlots = 0
    local freeSlots = 0

    for bag = 0, NUM_BAG_SLOTS do
        local slots = C_Container.GetContainerNumSlots(bag)
        if slots and slots > 0 then
            totalSlots = totalSlots + slots

            local free = C_Container.GetContainerNumFreeSlots(bag)
            if free and free > 0 then
                freeSlots = freeSlots + free
            end
        end
    end

    local usedSlots = totalSlots - freeSlots
    local percentUsed = (totalSlots > 0) and (usedSlots / totalSlots) or 0

    return usedSlots, freeSlots, totalSlots, percentUsed
end

local function BagsAtOrAboveThreshold()
    -- notes: Convenience wrapper that returns true when bag usage >= BAG_USAGE_THRESHOLD.
    local _, _, totalSlots, percentUsed = GetBagUsage()
    if totalSlots <= 0 then return false end
    return percentUsed >= GetBagUsageThreshold()
end

-------------------------------------------------
-- Button
-------------------------------------------------
local SavePopupButtonPosition
local ApplyPopupButtonPosition
local ResetPopupButtonPosition

local button = CreateFrame("Button", "AutoJunkDestroyerButton", UIParent, "UIPanelButtonTemplate")
button:SetSize(180, 30)
button:SetPoint("CENTER")
button:SetMovable(true)
button:EnableMouse(true)
button:RegisterForDrag("LeftButton")
button:SetScript("OnDragStart", function(self)
    -- notes: Dragging is blocked when paused, in BG, or in combat (prevents protected/taint issues).
    if paused or inBattleground or InCombat() then return end
    self:StartMoving()
end)
button:SetScript("OnDragStop", function(self)
    -- notes: Stops movement and persists the new position to SavedVariables.
    self:StopMovingOrSizing()
    SavePopupButtonPosition()
end)
button:Hide()

-- Keep the popup on-screen
button:SetClampedToScreen(true)

-------------------------------------------------
-- Popup Button Position Persistence (SavedVariables)
-- Saved to AutoJunkDestroyerDB.popupButtonPos so it will appear on disk.
-------------------------------------------------

SavePopupButtonPosition = function()
    -- notes: Saves button position into AutoJunkDestroyerDB.popupButtonPos.
    -- notes: Uses UIParent CENTER-relative offsets so it survives resolution/UI scale changes better.
    -- notes: Skips saving while disabled/in BG/in combat to avoid bad/tainted state writes.
    if paused or inBattleground or InCombat() then return end
    EnsureSV()

    local bx, by = button:GetCenter()
    local ux, uy = UIParent:GetCenter()
    if not bx or not by or not ux or not uy then return end

    AutoJunkDestroyerDB.popupButtonPos = {
        point = "CENTER",
        relPoint = "CENTER",
        x = bx - ux,
        y = by - uy,
        uiScale = UIParent:GetEffectiveScale(),
    }
end

ApplyPopupButtonPosition = function()
    -- notes: Restores the button position from AutoJunkDestroyerDB.popupButtonPos (if present).
    -- notes: Supports both the newer CENTER-relative format and the older absolute TOPLEFT coords.
    EnsureSV()
    local p = AutoJunkDestroyerDB.popupButtonPos
    if not p then return end

    button:ClearAllPoints()

    -- New format (preferred)
    if p.point and type(p.x) == "number" and type(p.y) == "number" then
        button:SetPoint(p.point, UIParent, p.relPoint or "CENTER", p.x, p.y)
        return
    end

    -- Legacy format fallback: absolute screen coords anchored via UIParent bottom-left
    if type(p.x) == "number" and type(p.y) == "number" then
        button:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", p.x, p.y)
    end
end

ResetPopupButtonPosition = function()
    -- notes: Clears saved popup position and re-centers the button.
    EnsureSV()
    AutoJunkDestroyerDB.popupButtonPos = nil
    button:ClearAllPoints()
    button:SetPoint("CENTER")
end


-------------------------------------------------
-- Button Text / Visibility
-------------------------------------------------
local function SetButtonCount(count)
    -- notes: Sets button label; includes remaining grey count when > 0.
    if count and count > 0 then
        button:SetText(string.format(L["BTN_DELETE_GREY_COUNT"], count))
    else
        button:SetText(L["BTN_DELETE_GREY"])
    end
end

local function UpdateButtonText(greys)
    -- notes: Updates the displayed count on the button. Accepts an optional pre-scanned greys table.
    greys = greys or GetGreyItems()
    SetButtonCount(#greys)
end

local function UpdateButtonVisibility(auto)
    -- notes: Controls when the delete button is shown/hidden based on:
    -- notes: - disabled states (paused/BG/combat) -> always hidden
    -- notes: - auto mode: show when bags are >= threshold and greys exist (or keep visible while greys remain)
    if paused or inBattleground or InCombat() then
        button:Hide()
        return
    end


    -- During reload/zone transitions, bag APIs can report transient values.
    -- Avoid auto-pop until bags have stabilized.
    if auto and booting then
        button:Hide()
        return
    end

    local greys = GetGreyItems()

    -- Show trigger: bags at/above threshold.
    -- Keep-visible behavior: once shown, stay shown while greys remain
    -- (prevents hiding after freeing 1 slot when you delete just one item).
    if auto then
        if (#greys > 0) and (BagsAtOrAboveThreshold() or button:IsShown()) then
            button:Show()
            SetButtonCount(#greys)
        else
            button:Hide()
        end
    end
end


local function ScheduleBagRefresh(delaySeconds)
    -- notes: Debounces bag refreshes (bag update events can fire many times).
    -- notes: Default delay is small to allow bag APIs to settle.
    if bagRefreshPending then return end
    bagRefreshPending = true
    C_Timer.After(delaySeconds or 0.15, function()
        bagRefreshPending = false
        if paused or inBattleground or InCombat() then
            button:Hide()
            return
        end
        UpdateButtonVisibility(true)
    end)
end

-------------------------------------------------
-- Enable logic (combat-safe)
-------------------------------------------------
local function EnableAddonNow()
    -- notes: Re-enables addon state after leaving BG (only if not actually still in BG).
    -- notes: Resets queues/flags, restores pause state, and refreshes button visibility.
    if IsInBattleground() then return end

    pendingEnableAfterCombat = false
    warnedWaitingForCombat = false

    inBattleground = false
    paused = userPaused

    Print(L["MSG_LEFT_BG_ENABLED"])
    UpdateButtonVisibility(true)
end

local function DelayedEnableAfterBG()
    -- notes: After BG exit, waits BG_EXIT_DELAY seconds to avoid zoning-related UI/protected action errors.
    -- notes: If still in combat at that time, defers enable until combat ends.
    C_Timer.After(BG_EXIT_DELAY, function()
        if IsInBattleground() then return end

        if InCombat() then
            pendingEnableAfterCombat = true
            button:Hide()
            if not warnedWaitingForCombat then
                Print(L["MSG_LEFT_BG_WAIT_COMBAT"])
                warnedWaitingForCombat = true
            end
            return
        end

        EnableAddonNow()
    end)
end

local function SetBattlegroundState(isInBG)
    -- notes: Central BG state handler:
    -- notes: - entering BG: force pause/disable and hide UI
    -- notes: - leaving BG: schedule delayed enable (combat/zoning safe)
    local wasInBG = inBattleground
    inBattleground = isInBG

    paused = userPaused or inBattleground

    if inBattleground then
        pendingEnableAfterCombat = false
        warnedWaitingForCombat = false
        button:Hide()
        if not wasInBG then
            Print(L["MSG_ENTER_BG_DISABLED"])
        end
    else
        if wasInBG then
            DelayedEnableAfterBG()
        else
            UpdateButtonVisibility(true)
        end
    end
end

local function OnEnterCombat()
    -- notes: Combat entry handler; hides button to avoid protected action issues during combat.
    button:Hide()
end

local function OnLeaveCombat()
    -- notes: Combat exit handler:
    -- notes: - if we were waiting to re-enable after BG exit, re-enable now
    -- notes: - otherwise refresh visibility if addon is active
    warnedWaitingForCombat = false

    if pendingEnableAfterCombat and not IsInBattleground() then
        EnableAddonNow()
        return
    end

    if not paused and not inBattleground then
        UpdateButtonVisibility(true)
    end
end

-------------------------------------------------
-- Safe Deletion (1 item per click)
-------------------------------------------------
button:SetScript("OnClick", function()
    -- notes: Click handler deletes exactly ONE grey item per click (combat/BG-safe).
    -- notes: Rescans every click so counts stay accurate and avoids stale bag/slot pointers.
    if paused or inBattleground or InCombat() then
        Print(L["MSG_CANNOT_DELETE"])
        return
    end

    -- Always rescan so the count stays accurate after each deletion.
    local greys = GetGreyItems()
    local count = #greys

    if count == 0 then
        Print(L["MSG_NO_GREY"])
        SetButtonCount(0)
        UpdateButtonVisibility(true)
        return
    end

    -- Delete ONE item (first grey found)
    local item = greys[1]
    local bag, slot = item.bag, item.slot

    C_Container.PickupContainerItem(bag, slot)
    if CursorHasItem() then
        DeleteCursorItem()
        ClearCursor()
    end

    -- Bags update slightly after deletion; rescan shortly after to update the display.
    C_Timer.After(0.10, function()
        local remaining = GetGreyItems()
        local rcount = #remaining
        SetButtonCount(rcount)

        if rcount > 0 then
            Print(string.format(L["MSG_REMAINING"], rcount))
        else
            Print(L["MSG_ALL_DELETED"])
        end

        UpdateButtonText()
        UpdateButtonVisibility(true)
    end)
end)

-------------------------------------------------
-- AceDB + Minimap (LibDBIcon)
-------------------------------------------------
local db -- AceDB database object (db.profile.*)
local icon = LibStub("LibDBIcon-1.0")
local LDB  = LibStub("LibDataBroker-1.1")


-- Forward declarations for Soul Shard helpers (must exist before minimap OnClick handler)
local CountSoulShards
local CreateShardButtonFrame
local RefreshShardUI
local shardFrame, shardButton

local pendingShardDeletePrint
local pendingShardDeleteLink
local pendingShardDeleteAt

local AJD_LDB = LDB:NewDataObject("AutoJunkDestroyer", {
    
type = "data source",
    text = "AutoJunkDestroyer",
    icon = "Interface\\ICONS\\INV_Misc_Bag_08",

    OnClick = function(_, mouseButton)
        -- notes: Minimap icon click toggles the popup delete button (when addon is active).
-- Right-click: toggle Soul Shard delete button (only if shards exist)
if mouseButton == "RightButton" then
    if CountSoulShards() == 0 then
        Print(L["MSG_NO_SHARDS"])
        return
    end

    CreateShardButtonFrame()
    if shardFrame:IsShown() then
        shardFrame:Hide()
    else
        RefreshShardUI()
        shardFrame:Show()
    end
    return
end

        if paused or inBattleground or InCombat() then
            Print(L["MSG_DISABLED_RIGHT_NOW"])
            button:Hide()
            return
        end

        if button:IsShown() then
            button:Hide()
            Print(L["MSG_BUTTON_HIDDEN_MINIMAP"])
        else
            button:Show()
            UpdateButtonText()
            Print(L["MSG_BUTTON_SHOWN_MINIMAP"])
        end
    end,

    OnTooltipShow = function(tt)
        -- notes: Tooltip helper for minimap icon; displays quick usage hints.
        tt:AddLine(L["TOOLTIP_TITLE"])
        tt:AddLine(L["TOOLTIP_LEFTCLICK"])
        tt:AddLine(L["TOOLTIP_RIGHTCLICK"])
        tt:AddLine(L["TOOLTIP_DRAG"])
        tt:AddLine(L["TOOLTIP_CMD"])
    end,
})

local function InitAceDB()
    -- notes: Initializes AceDB and registers LibDBIcon using db.profile.minimap as the storage table.
    -- notes: This ensures minimap icon position/hide/lock persist reliably.
    local AceDB = LibStub("AceDB-3.0", true)
    if not AceDB then
        Print(L["ERR_ACEDB_MISSING"])
        return
    end

    -- IMPORTANT:
    -- AutoJunkDestroyer uses AutoJunkDestroyerDB for its own SavedVariables (settings, popup positions, etc.).
    -- Using the same table for AceDB causes structure collisions and can crash on PLAYER_LOGOUT when AceDB tries
    -- to clean up "profile" sections (e.g., calling next() on boolean values).
    --
    -- So we keep our main SavedVariables table as-is and give AceDB its own dedicated SavedVariables table.
    -- This fixes the logout error WITHOUT modifying AceDB itself.
    if AutoJunkDestroyerIconDB ~= nil and type(AutoJunkDestroyerIconDB) ~= "table" then
        AutoJunkDestroyerIconDB = nil
    end
    AutoJunkDestroyerIconDB = AutoJunkDestroyerIconDB or {}

    -- HARDENING: AceDB expects sv.profile to be a table of profileName => table.
    -- If sv.profile contains non-table values (e.g. _setupComplete=true) AceDB will crash on logout (next(boolean)).
    local function AJD_SanitizeAceDBSV(sv)
        if type(sv) ~= "table" then return end
        if type(sv.profileKeys) ~= "table" then sv.profileKeys = {} end
        if type(sv.profiles) ~= "table" then sv.profiles = {} end
        if type(sv.profile) ~= "table" then sv.profile = {} end

        local realmKey = (GetRealmName and GetRealmName()) or ""
        local playerName = (UnitName and UnitName("player")) or "Player"
        local charKey = playerName .. " - " .. realmKey
        local profileName = sv.profileKeys[charKey]
        if type(profileName) ~= "string" or profileName == "" then
            -- pick any existing profile name if present, otherwise default to charKey
            for _, v in pairs(sv.profileKeys) do
                if type(v) == "string" and v ~= "" then profileName = v break end
            end
            profileName = profileName or charKey
            sv.profileKeys[charKey] = profileName
        end

        -- Decide whether sv.profile is already a map of tables. In a valid map, ALL values are tables.
        local allTables = true
        for _, v in pairs(sv.profile) do
            if type(v) ~= "table" then allTables = false break end
        end

        if not allTables then
            -- sv.profile is a flat profile table (or mixed garbage). Wrap it under the active profile name.
            local flat = sv.profile
            sv.profile = {}
            sv.profile[profileName] = (type(flat) == "table") and flat or {}
        else
            if type(sv.profile[profileName]) ~= "table" then
                sv.profile[profileName] = {}
            end
        end

        -- Final guard: ensure every entry in sv.profile is a table.
        for k, v in pairs(sv.profile) do
            if type(v) ~= "table" then sv.profile[k] = nil end
        end
    end

    -- Sanitize the SV table BEFORE creating the db.
    AJD_SanitizeAceDBSV(AutoJunkDestroyerIconDB)

    -- Install a pre-logout guard by wrapping AceDB.frame OnEvent so we sanitize BEFORE AceDB cleans up.
    -- Compatibility note: this depends on stable AceDB internals (frame/GetScript/SetScript); if those
    -- internals change, we skip wrapping and continue safely without crashing.
    if not AceDB.__AJD_PreLogoutWrapped and AceDB.frame and AceDB.frame.GetScript and AceDB.frame.SetScript then
        local frame = AceDB.frame
        local orig = frame:GetScript("OnEvent")
        frame:SetScript("OnEvent", function(self, event, ...)
            if event == "PLAYER_LOGOUT" then
                -- sanitize our own store by name (covers cases where db_registry is missing/corrupted)
                AJD_SanitizeAceDBSV(_G.AutoJunkDestroyerIconDB)
                -- sanitize every AceDB-registered database sv, BEFORE AceDB cleanup runs
                for adb in pairs(AceDB.db_registry or {}) do
                    local svt = rawget(adb, "sv")
                    AJD_SanitizeAceDBSV(svt)
                end
            end
            if orig then return orig(self, event, ...) end
        end)
        AceDB.__AJD_PreLogoutWrapped = true
    else
        DebugPrint("AceDB pre-logout wrapper skipped (unexpected AceDB frame internals)")
    end


    -- One-time migration: if a previous version stored minimap data under AutoJunkDestroyerDB.profile.minimap,
    -- carry it over to the new AceDB store so the icon position/hide/lock are preserved.
    local migratedMinimap
    if type(AutoJunkDestroyerDB) == "table" and type(AutoJunkDestroyerDB.profile) == "table" and type(AutoJunkDestroyerDB.profile.minimap) == "table" then
        migratedMinimap = AutoJunkDestroyerDB.profile.minimap
    end

    local defaults = {
        profile = {
            minimap = {
                hide = false,
                lock = false,
                minimapPos = 220,
            },
        },
    }

    db = AceDB:New("AutoJunkDestroyerIconDB", defaults, true)

	-- One-time SV cleanup: early broken builds stored arbitrary keys directly under sv.profile (flat table)
	-- which then got wrapped under the active profile. That leftover junk is not used by LibDBIcon and can
	-- re-corrupt the structure if other code merges tables later. We keep ONLY 'minimap' under the active
	-- profile, and back up any legacy keys once.
	if type(_G.AutoJunkDestroyerIconDB) == "table" and not _G.AutoJunkDestroyerIconDB.__AJD_SV_Migrated7 then
		local sv = _G.AutoJunkDestroyerIconDB
		local realmKey = (GetRealmName and GetRealmName()) or ""
		local playerName = (UnitName and UnitName("player")) or "Player"
		local charKey = playerName .. " - " .. realmKey
		local profileName = (type(sv.profileKeys) == "table") and sv.profileKeys[charKey] or nil
		if type(profileName) ~= "string" or profileName == "" then profileName = charKey end
		if type(sv.profile) == "table" and type(sv.profile[profileName]) == "table" then
			local p = sv.profile[profileName]
			local backup = nil
			for k, v in pairs(p) do
				if k ~= "minimap" then
					backup = backup or {}
					backup[k] = v
					p[k] = nil
				end
			end
			if backup then
				sv.__AJD_SV_LegacyBackup7 = backup
			end
		end
		sv.__AJD_SV_Migrated7 = true
	end

    if migratedMinimap and type(db.profile) == "table" and type(db.profile.minimap) == "table" then
        for k, v in pairs(migratedMinimap) do
            db.profile.minimap[k] = v
        end
    end

    -- Register LibDBIcon against db.profile.minimap (this is the standard working pattern)
    icon:Register("AutoJunkDestroyer", AJD_LDB, db.profile.minimap)
    icon:Refresh("AutoJunkDestroyer", db.profile.minimap)

    Print(L["MSG_MINIMAP_ACEDB_OK"])
end

-------------------------------------------------
-- Slash Command Action Exports (implemented in Commands.lua)
-------------------------------------------------
AJD.Print = Print
AJD.L = L
AJD.IsDisabledNow = function()
    return paused or inBattleground or InCombat()
end
AJD.TogglePause = function()
    userPaused = not userPaused
    paused = userPaused or inBattleground
    Print(userPaused and L["MSG_PAUSED"] or L["MSG_RESUMED"])
    UpdateButtonVisibility(true)
end
AJD.Resume = function()
    userPaused = false
    paused = inBattleground
    Print(L["MSG_RESUMED"])
    UpdateButtonVisibility(true)
end
AJD.PrintStatus = function()
    Print(string.format(L["MSG_STATUS"], tostring(userPaused), tostring(paused), tostring(inBattleground), tostring(InCombat()), tostring(button:IsShown())))
end
AJD.SetThreshold = function(arg)
    EnsureSV()
    if arg == "" then
        Print(string.format(L["MSG_THRESHOLD_CURRENT"], math.floor(GetBagUsageThreshold() * 100 + 0.5)))
        return
    end

    local v = tonumber(arg)
    if not v then
        Print(L["MSG_THRESHOLD_USAGE"])
        return
    end

    if v > 1.0 then v = v / 100 end
    if v < 0.50 then v = 0.50 end
    if v > 0.99 then v = 0.99 end

    AutoJunkDestroyerDB.settings.bagUsageThreshold = v
    Print(string.format(L["MSG_THRESHOLD_SET"], math.floor(v * 100 + 0.5)))
    ScheduleBagRefresh(0)
end
AJD.HandleButtonCommand = function(arg)
    if arg == "reset" then
        ResetPopupButtonPosition()
        Print(L["MSG_POPUP_RESET"])
        return
    end

    EnsureSV()
    local p = AutoJunkDestroyerDB.popupButtonPos
    if p then
        if p.point then
            Print(string.format(L["MSG_POPUP_POS_SAVED_REL"], tostring(p.x), tostring(p.y), tostring(p.point)))
        else
            Print(string.format(L["MSG_POPUP_POS_SAVED_ABS"], tostring(p.x), tostring(p.y)))
        end
    else
        local l, t = button:GetLeft(), button:GetTop()
        Print(string.format(L["MSG_POPUP_POS_NOT_SAVED"], tostring(l), tostring(t)))
    end
end
AJD.HandleMinimapCommand = function(arg)
    if not db then
        Print(L["MSG_MINIMAP_DB_NOT_READY"])
        return
    end

    if arg == "hide" then
        db.profile.minimap.hide = true
        icon:Hide("AutoJunkDestroyer")
        Print(L["MSG_MINIMAP_ICON_HIDDEN"])
    elseif arg == "show" then
        db.profile.minimap.hide = false
        icon:Show("AutoJunkDestroyer")
        Print(L["MSG_MINIMAP_ICON_SHOWN"])
    elseif arg == "lock" then
        db.profile.minimap.lock = true
        icon:Lock("AutoJunkDestroyer")
        Print(L["MSG_MINIMAP_LOCKED"])
    elseif arg == "unlock" then
        db.profile.minimap.lock = false
        icon:Unlock("AutoJunkDestroyer")
        Print(L["MSG_MINIMAP_UNLOCKED"])
    elseif arg == "reset" then
        db.profile.minimap.minimapPos = 220
        icon:Refresh("AutoJunkDestroyer", db.profile.minimap)
        Print(L["MSG_MINIMAP_RESET"])
    elseif arg == "pos" or arg == "" then
        Print(string.format(L["MSG_MINIMAP_POS_SAVED"], tostring(db.profile.minimap.minimapPos), tostring(db.profile.minimap.hide), tostring(db.profile.minimap.lock)))
    else
        Print(L["MSG_MINIMAP_USAGE"])
    end
end
AJD.TogglePopup = function()
    if paused or inBattleground or InCombat() then
        Print(L["MSG_DISABLED_RIGHT_NOW"])
        button:Hide()
        return
    end

    if button:IsShown() then
        button:Hide()
        Print(L["MSG_BUTTON_HIDDEN_MINIMAP"])
    else
        button:Show()
        UpdateButtonText()
        Print(L["MSG_BUTTON_SHOWN_MINIMAP"])
    end
end
AJD.PrintHelp = function()
    Print(L["MSG_HELP_PAUSE"])
    Print(L["MSG_HELP_RESUME"])
    Print(L["MSG_HELP_STATUS"])
    Print(L["MSG_HELP_TOGGLE"])
    Print(L["MSG_HELP_THRESHOLD"])
    Print(L["MSG_HELP_MINIMAP_RESET"])
end

-------------------------------------------------
-- Events
-------------------------------------------------
frame:RegisterEvent("PLAYER_LOGIN")
frame:RegisterEvent("PLAYER_ENTERING_WORLD")
frame:RegisterEvent("BAG_UPDATE_DELAYED")
frame:RegisterEvent("PLAYER_REGEN_DISABLED")
frame:RegisterEvent("PLAYER_REGEN_ENABLED")
frame:RegisterEvent("PLAYER_LOGOUT")

-------------------------------------------------
-- Soul Shard Helpers (Warlock)
--   - Right-click minimap icon toggles a movable button
--   - Button only appears if shards exist
--   - One click = delete one shard (Blizzard-safe)
--   - Chat output + remaining count synced to BAG_UPDATE_DELAYED
-------------------------------------------------

-- Soul Shard item ID (Classic)
local SOUL_SHARD_ITEM_ID = 6265

CountSoulShards = function()
    local total = 0
    for bag = 0, NUM_BAG_SLOTS do
        local slots = C_Container.GetContainerNumSlots(bag)
        if slots and slots > 0 then
            for slot = 1, slots do
                local info = C_Container.GetContainerItemInfo(bag, slot)
                if info and info.itemID == SOUL_SHARD_ITEM_ID then
                    total = total + (info.stackCount or 1)
                end
            end
        end
    end
    return total
end

local function FindSoulShardSlot()
    for bag = 0, NUM_BAG_SLOTS do
        local slots = C_Container.GetContainerNumSlots(bag)
        if slots and slots > 0 then
            for slot = 1, slots do
                local info = C_Container.GetContainerItemInfo(bag, slot)
                if info and info.itemID == SOUL_SHARD_ITEM_ID then
                    return bag, slot, info
                end
            end
        end
    end
    return nil
end

local function DeleteSoulShardOnce()
    if InCombatLockdown() then
        Print(L["CANNOT_DELETE_IN_COMBAT"])
        return false
    end
    if IsInBattleground() then
        Print(L["CANNOT_DELETE_IN_BATTLEGROUNDS"])
        return false
    end
    if CursorHasItem() then
        Print(L["CURSOR_HOLDING_ITEM_CLEAR_FIRST"])
        return false
    end

    local bag, slot, info = FindSoulShardSlot()
    if not bag then
        Print(L["NO_SOUL_SHARDS_FOUND"])
        return false
    end

    local link = (info and info.hyperlink) or L["SOUL_SHARD"]

    C_Container.PickupContainerItem(bag, slot)
    if not CursorHasItem() then
        Print(L["FAILED_PICKUP_SOUL_SHARD"])
        return false
    end

    DeleteCursorItem()

    -- Defer chat output until BAG_UPDATE_DELAYED so the count matches the button.
    pendingShardDeletePrint = true
    pendingShardDeleteLink = link
    pendingShardDeleteAt = GetTime()

    -- Mirror grey-delete behavior: trigger the normal bag refresh path.
    if ScheduleBagRefresh then
        ScheduleBagRefresh()
    end

    -- Fallback: if BAG_UPDATE_DELAYED doesn't arrive (rare), print after a short delay.
    C_Timer.After(0.75, function()
        if pendingShardDeletePrint and pendingShardDeleteAt and (GetTime() - pendingShardDeleteAt) >= 0.70 then
            local remaining = CountSoulShards()
            Print((L["DELETED_ITEM_REMAINING_SHARDS"]):format(pendingShardDeleteLink or L["SOUL_SHARD"], remaining))
            pendingShardDeletePrint = nil
            pendingShardDeleteLink = nil
            pendingShardDeleteAt = nil
            if RefreshShardUI then RefreshShardUI() end
        end
    end)

    return true
end
RefreshShardUI = function()
    if not shardButton then return end
    local n = CountSoulShards()
    shardButton:SetText((L["DELETE_SOUL_SHARDS_BUTTON"]):format(n))
    shardButton:SetEnabled(n > 0 and not InCombatLockdown() and not IsInBattleground() and not CursorHasItem())

    if shardFrame and shardFrame:IsShown() then
        if n == 0 then
            shardFrame:Hide()
        end
    end
end

CreateShardButtonFrame = function()
    if shardFrame then return end

    shardFrame = CreateFrame("Button", "AutoJunkDestroyer_ShardButton", UIParent, "UIPanelButtonTemplate")
    shardFrame:SetSize(200, 24)
    shardFrame:SetFrameStrata("DIALOG")
    shardFrame:SetClampedToScreen(true)
    shardFrame:SetMovable(true)
    shardFrame:EnableMouse(true)
    shardFrame:RegisterForDrag("LeftButton")

    shardFrame:SetScript("OnDragStart", function(self)
        if InCombatLockdown() then return end
        self:StartMoving()
    end)
    shardFrame:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        EnsureSV()
        local point, _, _, x, y = self:GetPoint(1)
        AutoJunkDestroyerDB.settings.shardButtonPos = AutoJunkDestroyerDB.settings.shardButtonPos or {}
        AutoJunkDestroyerDB.settings.shardButtonPos.point = point or "CENTER"
        AutoJunkDestroyerDB.settings.shardButtonPos.x = x or 0
        AutoJunkDestroyerDB.settings.shardButtonPos.y = y or 0
    end)

    shardButton = shardFrame
    shardButton:SetScript("OnClick", function()
        DeleteSoulShardOnce()
    end)

    -- Restore saved position
    EnsureSV()
    local pos = AutoJunkDestroyerDB.settings and AutoJunkDestroyerDB.settings.shardButtonPos
    shardFrame:ClearAllPoints()
    if pos and pos.point then
        shardFrame:SetPoint(pos.point, UIParent, pos.point, pos.x or 0, pos.y or 0)
    else
        shardFrame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    end

        RefreshShardUI()

    shardFrame:Hide()
end

frame:SetScript("OnEvent", function(_, event)
    -- notes: Central event dispatcher; keeps addon state in sync with login, zoning, combat, and bag changes.
    if event == "PLAYER_LOGIN" then
        booting = true
        -- notes: Initialize persistent systems and apply saved UI position.
        InitAceDB()
        ApplyPopupButtonPosition()
        SetBattlegroundState(IsInBattleground())
        C_Timer.After(0.75, function()
            booting = false
            ScheduleBagRefresh(0)
        end)
        Print(L["MSG_LOADED"])
    elseif event == "PLAYER_ENTERING_WORLD" then
        booting = true
        -- notes: Fires during zoning/instance changes; used to update BG state on transitions.
        SetBattlegroundState(IsInBattleground())
        C_Timer.After(0.75, function()
            booting = false
            ScheduleBagRefresh(0)
        end)

    elseif event == "PLAYER_REGEN_DISABLED" then
        -- notes: Entering combat.
        OnEnterCombat()

    elseif event == "PLAYER_REGEN_ENABLED" then
        -- notes: Leaving combat.
        OnLeaveCombat()

    elseif event == "PLAYER_LOGOUT" then
        -- notes: Persist popup position at logout (best-effort; guarded inside function).
        SavePopupButtonPosition()

    elseif event == "BAG_UPDATE_DELAYED" then
        -- notes: Updates button visibility when bags change (only when safe/active).
        if not paused and not inBattleground and not InCombat() then
            UpdateButtonVisibility(true)
        end

        RefreshShardUI()

        -- One-shot shard deletion chat print (sync to bag updates)
        if pendingShardDeletePrint then
            local remaining = CountSoulShards()
            Print((L["DELETED_ITEM_REMAINING_SHARDS"]):format(pendingShardDeleteLink or L["SOUL_SHARD"], remaining))
            pendingShardDeletePrint = nil
            pendingShardDeleteLink = nil
            pendingShardDeleteAt = nil
        end
    end
end)
