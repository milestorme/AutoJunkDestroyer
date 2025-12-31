-- File: AutoJunkDestroyer.lua
-- Name: Auto Junk Destroyer
-- Author: Milestorme
-- Description: Destroy junk items when bags are full easily
-- Safe, BG-aware, works with any number of bags
-- Version: 1.0.3

local ADDON_NAME = ...
local frame = CreateFrame("Frame")

-- userPaused = what the player chose via /ajd pause
-- paused = effective pause state (userPaused OR inBattleground)
local userPaused = false
local paused = false
local inBattleground = false

local greyQueue = {}
local deleting = false

-- Delay after leaving battleground to avoid UI errors during zoning
local BG_EXIT_DELAY = 1.0

-- If we leave a BG while in combat, we defer enabling until combat ends.
local pendingEnableAfterCombat = false

-- Prevent chat spam when leaving BG during combat
local warnedWaitingForCombat = false

-------------------------------------------------
-- Utility
-------------------------------------------------
local function Print(msg)
    DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00AutoJunkDestroyer:|r " .. msg)
end

local function IsInBattleground()
    local instanceType = select(2, IsInInstance())
    return instanceType == "pvp"
end

local function InCombat()
    return (InCombatLockdown and InCombatLockdown()) or UnitAffectingCombat("player")
end

-------------------------------------------------
-- Grey Item Scan
-------------------------------------------------
local function GetGreyItems()
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

local function BagsAreFull()
    for bag = 0, NUM_BAG_SLOTS do
        local free = C_Container.GetContainerNumFreeSlots(bag)
        if free and free > 0 then
            return false
        end
    end
    return true
end

-------------------------------------------------
-- Button
-------------------------------------------------
local button = CreateFrame("Button", "AutoJunkDestroyerButton", UIParent, "UIPanelButtonTemplate")
button:SetSize(180, 30)
button:SetPoint("CENTER")
button:SetMovable(true)
button:EnableMouse(true)
button:RegisterForDrag("LeftButton")
button:SetScript("OnDragStart", button.StartMoving)
button:SetScript("OnDragStop", button.StopMovingOrSizing)
button:Hide()

-------------------------------------------------
-- Button Text / Visibility
-------------------------------------------------
local function SetButtonCount(count)
    if count and count > 0 then
        button:SetText("Delete Grey Items (" .. count .. ")")
    else
        button:SetText("Delete Grey Items")
    end
end

local function UpdateButtonText()
    local greys = GetGreyItems()
    SetButtonCount(#greys)
end

local function UpdateButtonVisibility(auto)
    -- Never show in BG, while paused, or during combat
    if paused or inBattleground or InCombat() then
        button:Hide()
        return
    end

    local greys = GetGreyItems()
    if auto and BagsAreFull() and #greys > 0 then
        button:Show()
        SetButtonCount(#greys)
    elseif auto then
        button:Hide()
    end
end

-------------------------------------------------
-- Enable logic (combat-safe)
-------------------------------------------------
local function EnableAddonNow()
    -- If we re-entered a BG, do nothing
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
    C_Timer.After(BG_EXIT_DELAY, function()
        -- If we re-entered a BG during the delay, do nothing
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

-------------------------------------------------
-- Battleground state handler
-------------------------------------------------
local function SetBattlegroundState(isInBG)
    local wasInBG = inBattleground
    inBattleground = isInBG

    -- paused derived from userPaused OR battleground
    paused = userPaused or inBattleground

    if inBattleground then
        -- Hard-disable behavior in BG
        pendingEnableAfterCombat = false
        warnedWaitingForCombat = false
        deleting = false
        greyQueue = {}
        button:Hide()

        if not wasInBG then
            Print("Entered battleground — addon disabled.")
        end
    else
        -- Delay re-enable to avoid UI taint/errors during zone load
        if wasInBG then
            DelayedEnableAfterBG()
        else
            UpdateButtonVisibility(true)
        end
    end
end

-------------------------------------------------
-- Combat handlers (instant hide/show)
-------------------------------------------------
local function OnEnterCombat()
    -- Immediately hide UI to prevent taint/protected action errors
    button:Hide()
end

local function OnLeaveCombat()
    -- Reset spam guard for the next time we might need it
    warnedWaitingForCombat = false

    -- Combat ended: if we were waiting to enable after leaving BG, enable now.
    if pendingEnableAfterCombat and not IsInBattleground() then
        EnableAddonNow()
        return
    end

    -- Otherwise just refresh visibility safely
    if not paused and not inBattleground then
        UpdateButtonVisibility(true)
    end
end

-------------------------------------------------
-- Safe Deletion (1 item per click)
-------------------------------------------------
button:SetScript("OnClick", function()
    if paused or inBattleground or InCombat() then
        Print("Cannot delete grey items right now.")
        return
    end

    if not deleting then
        greyQueue = GetGreyItems()
        deleting = true
        -- Sync button count immediately to the queue size
        SetButtonCount(#greyQueue)
    end

    if #greyQueue == 0 then
        deleting = false
        Print("No grey items to delete.")
        SetButtonCount(0)
        UpdateButtonVisibility(true)
        return
    end

    local item = table.remove(greyQueue, 1)

    ClearCursor()
    C_Container.PickupContainerItem(item.bag, item.slot)
    if CursorHasItem() then
        DeleteCursorItem()
    end

    if #greyQueue > 0 then
        Print(#greyQueue .. " grey items remaining. Click again.")
    else
        deleting = false
        Print("All grey items deleted.")
    end

    -- Update the number immediately using the queue (avoids bag-scan lag)
    SetButtonCount(#greyQueue)

    -- When finished, do a real rescan after the bag update settles
    if not deleting then
        C_Timer.After(0.05, function()
            UpdateButtonVisibility(true)
        end)
    end
end)

-------------------------------------------------
-- Slash Commands
-------------------------------------------------
SLASH_AUTOJUNKDESTROYER1 = "/ajd"
SlashCmdList.AUTOJUNKDESTROYER = function(msg)
    msg = (msg or ""):lower()

    if msg == "pause" then
        userPaused = not userPaused
        paused = userPaused or inBattleground

        if inBattleground then
            Print("Pause toggled, but you are in a battleground (addon remains disabled).")
            button:Hide()
        else
            Print(userPaused and "Paused." or "Resumed.")
            UpdateButtonVisibility(true)
        end

    elseif msg == "toggle" then
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

    else
        Print("/ajd pause  - Pause deletion")
        Print("/ajd toggle - Show/hide button")
    end
end

-------------------------------------------------
-- Minimap Icon (BugSack-style)
-------------------------------------------------
local LDB = LibStub("LibDataBroker-1.1")
local icon = LibStub("LibDBIcon-1.0")

local AJD_LDB = LDB:NewDataObject("AutoJunkDestroyer", {
    type = "data source",
    text = "AutoJunkDestroyer",
    icon = "Interface\\ICONS\\INV_Misc_Bag_08",
    OnClick = function()
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
        tt:AddLine("AutoJunkDestroyer")
        tt:AddLine("Left-click: Toggle delete button")
        tt:AddLine("Use /ajd pause to pause deletion")
    end,
})

AutoJunkDestroyerDB = AutoJunkDestroyerDB or {}
icon:Register("AutoJunkDestroyer", AJD_LDB, AutoJunkDestroyerDB)

-------------------------------------------------
-- Events
-------------------------------------------------
frame:RegisterEvent("PLAYER_LOGIN")
frame:RegisterEvent("PLAYER_ENTERING_WORLD")
frame:RegisterEvent("BAG_UPDATE")
frame:RegisterEvent("PLAYER_REGEN_DISABLED") -- enter combat
frame:RegisterEvent("PLAYER_REGEN_ENABLED")  -- leave combat

frame:SetScript("OnEvent", function(_, event)
    if event == "PLAYER_LOGIN" then
        SetBattlegroundState(IsInBattleground())
        Print("Loaded (Classic 1.15.8).")
        UpdateButtonVisibility(true)

    elseif event == "PLAYER_ENTERING_WORLD" then
        SetBattlegroundState(IsInBattleground())

    elseif event == "PLAYER_REGEN_DISABLED" then
        OnEnterCombat()

    elseif event == "PLAYER_REGEN_ENABLED" then
        OnLeaveCombat()

    elseif event == "BAG_UPDATE" then
        if not deleting and not paused and not inBattleground and not InCombat() then
            UpdateButtonVisibility(true)
        end
    end
end)
