local ADDON_NAME = ...
local AceLocale = LibStub("AceLocale-3.0")
local L = AceLocale:NewLocale("AutoJunkDestroyer", "enUS", true)
if not L then return end

L["ADDON_NAME"] = "AutoJunkDestroyer"
L["BTN_DELETE_GREY"] = "Delete Grey Items"
L["BTN_DELETE_GREY_COUNT"] = "Delete Grey Items (%d)"

L["MSG_CANNOT_DELETE"] = "Cannot delete grey items right now."
L["MSG_NO_GREY"] = "No grey items found."
L["MSG_REMAINING"] = "%d grey items remaining. Click again."
L["MSG_ALL_DELETED"] = "All grey items deleted."

L["MSG_LEFT_BG_ENABLED"] = "Left battleground — addon enabled."
L["MSG_LEFT_BG_WAIT_COMBAT"] = "Left battleground — waiting for combat to end to re-enable."
L["MSG_ENTER_BG_DISABLED"] = "Entered battleground — addon disabled."

L["MSG_PAUSED"] = "Paused."
L["MSG_RESUMED"] = "Resumed."

L["MSG_THRESHOLD_CURRENT"] = "Bag threshold is set to %d%%."
L["MSG_THRESHOLD_USAGE"] = "Usage: /ajd threshold 90   (or 0.90)"
L["MSG_THRESHOLD_SET"] = "Bag threshold set to %d%%."

L["MSG_POPUP_RESET"] = "Popup button position reset."

L["MSG_MINIMAP_DB_NOT_READY"] = "Minimap DB not ready yet."
L["MSG_MINIMAP_ICON_HIDDEN"] = "Minimap icon hidden."
L["MSG_MINIMAP_ICON_SHOWN"] = "Minimap icon shown."
L["MSG_MINIMAP_LOCKED"] = "Minimap icon locked."
L["MSG_MINIMAP_UNLOCKED"] = "Minimap icon unlocked."
L["MSG_MINIMAP_RESET"] = "Minimap icon reset."

L["MSG_BUTTON_HIDDEN_MINIMAP"] = "Button hidden via minimap."
L["MSG_BUTTON_SHOWN_MINIMAP"] = "Button shown via minimap."
L["MSG_DISABLED_RIGHT_NOW"] = "Addon is disabled right now (paused / battleground / combat)."

L["MSG_NO_SHARDS"] = "No Soul Shards to delete."

L["TOOLTIP_TITLE"] = "AutoJunkDestroyer"
L["TOOLTIP_LEFTCLICK"] = "Left-click: Toggle junk delete button"
L["TOOLTIP_RIGHTCLICK"] = "Right-click: Soul Shard delete popup"
L["TOOLTIP_DRAG"] = "Drag: Move minimap icon (saved via AceDB)"
L["TOOLTIP_CMD"] = "/ajd minimap hide|show|lock|unlock|reset"

L["ERR_ACEDB_MISSING"] = "ERROR: AceDB-3.0 not found. Make sure it’s included in Libs and listed in the TOC."
L["MSG_MINIMAP_ACEDB_OK"] = "Minimap: AceDB enabled (position will save)."
