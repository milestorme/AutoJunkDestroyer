-- File: AutoJunkDestroyer.lua
-- Name: Auto Junk Destroyer
-- Author: Milestorme
-- Description: Destroy junk items when bags are full easily
-- Safe, BG-aware, works with any number of bags
-- Version: 1.1.0
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
--   /ajd toggle                      -> Toggle popup visibility
--   /ajd button [reset]              -> Show/reset popup position
--   /ajd minimap [show|hide|lock|unlock|reset|pos]

-- Event Handling
--   PLAYER_LOGIN                     -> Initialization
--   PLAYER_ENTERING_WORLD            -> BG state detection
--   PLAYER_REGEN_DISABLED            -> Combat start
--   PLAYER_REGEN_ENABLED             -> Combat end
--   BAG_UPDATE                       -> Bag change handling
--   PLAYER_LOGOUT                    -> Persist saved data
-------------------------------------------------

local ADDON_NAME = ...
local frame = CreateFrame("Frame")

-- userPaused = what the player chose via /ajd pause
-- paused = effective pause state (userPaused OR inBattleground)
local userPaused = false
local paused = false
local inBattleground = false

local booting = true  -- true during reload/zone transitions; prevents early auto-pop
local greyQueue = {}
local deleting = false

-- Delay after leaving battleground to avoid UI errors during zoning
local BG_EXIT_DELAY = 0.5

-- If we leave a BG while in combat, we defer enabling until combat ends.
local pendingEnableAfterCombat = false
local warnedWaitingForCombat = false

-------------------------------------------------
-- Utility
-------------------------------------------------
local function Print(msg)
    -- notes: Unified chat output helper for consistent addon prefix formatting.
    DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00AutoJunkDestroyer:|r " .. msg)
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
local BAG_USAGE_THRESHOLD = 0.90

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
    return percentUsed >= BAG_USAGE_THRESHOLD
end

-------------------------------------------------
-- Button
-------------------------------------------------
local EnsureSV
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
EnsureSV = function()
    -- notes: Ensures SavedVariables table exists (created lazily to avoid nil access).
    AutoJunkDestroyerDB = AutoJunkDestroyerDB or {}
end

SavePopupButtonPosition = function()
    -- notes: Saves button TOP/LEFT screen coordinates into AutoJunkDestroyerDB.popupButtonPos.
    -- notes: Skips saving while disabled/in BG/in combat to avoid bad/tainted state writes.
    if paused or inBattleground or InCombat() then return end
    EnsureSV()

    -- Use absolute screen coords so the saved data always changes when you drag.
    local left = button:GetLeft()
    local top  = button:GetTop()
    if not left or not top then return end

    AutoJunkDestroyerDB.popupButtonPos = {
        x = left,
        y = top,
    }
end

ApplyPopupButtonPosition = function()
    -- notes: Restores the button position from AutoJunkDestroyerDB.popupButtonPos (if present).
    -- notes: Anchors TOPLEFT of the button to UIParent's BOTTOMLEFT using saved absolute coords.
    EnsureSV()
    local p = AutoJunkDestroyerDB.popupButtonPos
    if not p or not p.x or not p.y then return end

    button:ClearAllPoints()
    -- Place TOPLEFT of the button at saved screen coords
    button:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", p.x, p.y)
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
        button:SetText("Delete Grey Items (" .. count .. ")")
    else
        button:SetText("Delete Grey Items")
    end
end

local function UpdateButtonText()
    -- notes: Rescans grey items and updates the displayed count on the button.
    local greys = GetGreyItems()
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
    deleting = false
    greyQueue = {}

    Print("Left battleground — addon enabled.")
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
                Print("Left battleground — waiting for combat to end to re-enable.")
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
        deleting = false
        greyQueue = {}
        button:Hide()
        if not wasInBG then
            Print("Entered battleground — addon disabled.")
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
        Print("Cannot delete grey items right now.")
        return
    end

    -- Always rescan so the count stays accurate after each deletion.
    local greys = GetGreyItems()
    local count = #greys

    if count == 0 then
        Print("No grey items found.")
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
            Print(rcount .. " grey items remaining. Click again.")
        else
            Print("All grey items deleted.")
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

local AJD_LDB = LDB:NewDataObject("AutoJunkDestroyer", {
    type = "data source",
    text = "AutoJunkDestroyer",
    icon = "Interface\\ICONS\\INV_Misc_Bag_08",

    OnClick = function()
        -- notes: Minimap icon click toggles the popup delete button (when addon is active).
        if paused or inBattleground or InCombat() then
            Print("Addon is disabled right now (paused / battleground / combat).")
            button:Hide()
            return
        end

        if button:IsShown() then
            button:Hide()
            Print("Button hidden via minimap.")
        else
            button:Show()
            UpdateButtonText()
            Print("Button shown via minimap.")
        end
    end,

    OnTooltipShow = function(tt)
        -- notes: Tooltip helper for minimap icon; displays quick usage hints.
        tt:AddLine("AutoJunkDestroyer")
        tt:AddLine("Left-click: Toggle delete button")
        tt:AddLine("Drag: Move minimap icon (saved via AceDB)")
        tt:AddLine("/ajd minimap hide|show|lock|unlock|reset")
    end,
})

local function InitAceDB()
    -- notes: Initializes AceDB and registers LibDBIcon using db.profile.minimap as the storage table.
    -- notes: This ensures minimap icon position/hide/lock persist reliably.
    local AceDB = LibStub("AceDB-3.0", true)
    if not AceDB then
        Print("ERROR: AceDB-3.0 not found. Make sure it’s included in Libs and listed in the TOC.")
        return
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

    db = AceDB:New("AutoJunkDestroyerDB", defaults, true)

    -- Register LibDBIcon against db.profile.minimap (this is the standard working pattern)
    icon:Register("AutoJunkDestroyer", AJD_LDB, db.profile.minimap)
    icon:Refresh("AutoJunkDestroyer", db.profile.minimap)

    Print("Minimap: AceDB enabled (position will save).")
end

-------------------------------------------------
-- Slash Commands
-------------------------------------------------
SLASH_AUTOJUNKDESTROYER1 = "/ajd"
SlashCmdList.AUTOJUNKDESTROYER = function(msg)
    -- notes: Slash command router for /ajd.
    -- notes: Supports: pause, toggle, button [reset], minimap [hide/show/lock/unlock/reset/pos]
    msg = (msg or ""):lower()

    if msg == "pause" then
        userPaused = not userPaused
        paused = userPaused or inBattleground
        Print(userPaused and "Paused." or "Resumed.")
        UpdateButtonVisibility(true)
        return
    end

    if msg:match("^button") then
        -- notes: /ajd button -> prints saved popup position; /ajd button reset -> clears saved position.
        local arg = msg:match("^button%s*(.*)$") or ""
        arg = arg:lower()

        if arg == "reset" then
            ResetPopupButtonPosition()
            Print("Popup button position reset.")
        else
            EnsureSV()
            local p = AutoJunkDestroyerDB.popupButtonPos
            if p then
                Print("PopupPos (saved): x=" .. tostring(p.x) .. " y=" .. tostring(p.y))
            else
                local l, t = button:GetLeft(), button:GetTop()
                Print("PopupPos not saved yet. Current left=" .. tostring(l) .. " top=" .. tostring(t))
            end
        end
        return
    end

    if msg:match("^minimap") then
        -- notes: /ajd minimap controls LibDBIcon state (hide/show/lock/unlock/reset/pos).
        if not db then
            Print("Minimap DB not ready yet.")
            return
        end

        local arg = msg:match("^minimap%s*(.*)$") or ""
        arg = arg:lower()

        if arg == "hide" then
            db.profile.minimap.hide = true
            icon:Hide("AutoJunkDestroyer")
            Print("Minimap icon hidden.")
        elseif arg == "show" then
            db.profile.minimap.hide = false
            icon:Show("AutoJunkDestroyer")
            Print("Minimap icon shown.")
        elseif arg == "lock" then
            db.profile.minimap.lock = true
            icon:Lock("AutoJunkDestroyer")
            Print("Minimap icon locked.")
        elseif arg == "unlock" then
            db.profile.minimap.lock = false
            icon:Unlock("AutoJunkDestroyer")
            Print("Minimap icon unlocked.")
        elseif arg == "reset" then
            db.profile.minimap.minimapPos = 220
            icon:Refresh("AutoJunkDestroyer", db.profile.minimap)
            Print("Minimap icon position reset.")
        elseif arg == "pos" or arg == "" then
            Print("MinimapPos (saved): " .. tostring(db.profile.minimap.minimapPos) ..
                  " | hide=" .. tostring(db.profile.minimap.hide) ..
                  " | lock=" .. tostring(db.profile.minimap.lock))
        else
            Print("/ajd minimap reset")
        end
        return
    end

    if msg == "toggle" then
        -- notes: /ajd toggle shows/hides the popup delete button (only when addon is active).
        if paused or inBattleground or InCombat() then
            Print("Addon is disabled right now (paused / battleground / combat).")
            button:Hide()
            return
        end

        if button:IsShown() then
            button:Hide()
            Print("Button hidden.")
        else
            button:Show()
            UpdateButtonText()
            Print("Button shown.")
        end
        return
    end

    -- notes: Default help output.
    Print("/ajd pause")
    Print("/ajd toggle")
    Print("/ajd minimap reset")
end

-------------------------------------------------
-- Events
-------------------------------------------------
frame:RegisterEvent("PLAYER_LOGIN")
frame:RegisterEvent("PLAYER_ENTERING_WORLD")
frame:RegisterEvent("BAG_UPDATE")
frame:RegisterEvent("PLAYER_REGEN_DISABLED")
frame:RegisterEvent("PLAYER_REGEN_ENABLED")
frame:RegisterEvent("PLAYER_LOGOUT")

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
            if not paused and not inBattleground and not InCombat() then
                UpdateButtonVisibility(true)
            end
        end)
        Print("Loaded (Classic 1.15.8).")
        C_Timer.After(1.0, function()
            booting = false
            if not paused and not inBattleground and not InCombat() then
                UpdateButtonVisibility(true)
            end
        end)
    elseif event == "PLAYER_ENTERING_WORLD" then
        booting = true
        -- notes: Fires during zoning/instance changes; used to update BG state on transitions.
        SetBattlegroundState(IsInBattleground())

    elseif event == "PLAYER_REGEN_DISABLED" then
        -- notes: Entering combat.
        OnEnterCombat()

    elseif event == "PLAYER_REGEN_ENABLED" then
        -- notes: Leaving combat.
        OnLeaveCombat()

    elseif event == "PLAYER_LOGOUT" then
        -- notes: Persist popup position at logout (best-effort; guarded inside function).
        SavePopupButtonPosition()

    elseif event == "BAG_UPDATE" then
        -- notes: Updates button visibility when bags change (only when safe/active).
        if not deleting and not paused and not inBattleground and not InCombat() then
            UpdateButtonVisibility(true)
        end
    end
end)
