-- File: AutoJunkDestroyer.lua
-- Name: Auto Junk Destroyer
-- Author: Milestorme
-- Description: Automatically destroys junk items when bags are full
-- Version: 1.0.1

local frame = CreateFrame("Frame")
frame:RegisterEvent("PLAYER_ENTERING_WORLD")
frame:RegisterEvent("BAG_UPDATE")

local popupShown = false
local inBattleground = false

-- Check if player is in a battleground
local function IsInBattleground()
    local inInstance, instanceType = IsInInstance()
    return inInstance and instanceType == "pvp"
end

-- Get all grey (junk) items sorted by cheapest
local function GetJunkItems()
    local junkItems = {}
    for bag = 0, 4 do
        local slots = C_Container.GetContainerNumSlots(bag)
        if slots and slots > 0 then
            for slot = 1, slots do
                local info = C_Container.GetContainerItemInfo(bag, slot)
                if info and info.hyperlink then
                    local _, _, rarity, _, _, _, _, _, _, price = GetItemInfo(info.itemID)
                    if rarity == 0 and price and price > 0 then
                        table.insert(junkItems, {
                            bag = bag,
                            slot = slot,
                            price = price,
                            link = info.hyperlink
                        })
                    end
                end
            end
        end
    end
    table.sort(junkItems, function(a, b) return a.price < b.price end)
    return junkItems
end

-- Delete the first (cheapest) junk item
local function DeleteFirstJunkItem()
    local junkItems = GetJunkItems()
    if #junkItems == 0 then return end

    local item = junkItems[1]
    C_Container.PickupContainerItem(item.bag, item.slot)
    DeleteCursorItem()
    print("AutoJunkDestroyer: Destroyed", item.link)
end

-- Check if bags are full
local function BagsAreFull()
    for bag = 0, 4 do
        local slots = C_Container.GetContainerNumSlots(bag)
        if slots and slots > 0 then
            local free = C_Container.GetContainerNumFreeSlots(bag)
            if free and free > 0 then
                return false
            end
        end
    end
    return true
end

-- Show confirmation popup (one item only)
local function ShowConfirmationPopup()
    if popupShown or inBattleground then return end

    local junkItems = GetJunkItems()
    if #junkItems == 0 then return end

    popupShown = true

    StaticPopupDialogs["AUTJUNK_CONFIRM"] = {
        text = "Your bags are full!\nDelete the cheapest junk item?\n\n" .. junkItems[1].link,
        button1 = "Yes",
        button2 = "No",
        timeout = 0,
        whileDead = true,
        hideOnEscape = true,
        OnAccept = function()
            DeleteFirstJunkItem()
            popupShown = false
        end,
        OnCancel = function()
            popupShown = false
        end,
    }

    StaticPopup_Show("AUTJUNK_CONFIRM")
end

-- Event handler
frame:SetScript("OnEvent", function(self, event)
    if event == "PLAYER_ENTERING_WORLD" then
        inBattleground = IsInBattleground()
        print("AutoJunkDestroyer loaded!")
        return
    end

    -- Never run inside battlegrounds
    if IsInBattleground() then
        inBattleground = true
        return
    end

    -- Just left a battleground → wait for Blizzard cleanup
    if inBattleground then
        inBattleground = false
        C_Timer.After(1, function()
            if BagsAreFull() and #GetJunkItems() > 0 then
                ShowConfirmationPopup()
            end
        end)
        return
    end

    -- Normal behavior
    if BagsAreFull() and #GetJunkItems() > 0 then
        ShowConfirmationPopup()
    end
end)
