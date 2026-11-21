# AutoJunkDestroyer

**Keep your bags clear without hunting through stacks of vendor trash.**

AutoJunkDestroyer is a lightweight World of Warcraft addon by **Milestorme** that helps you remove grey-quality (junk) items when your bags fill up. It provides an on-demand deletion button, optional Soul Shard cleanup for Warlocks, and convenient minimap controls.

**Version:** 1.3.0  
**WoW Forever support:** 1.60.1

## Features

### Automatic bag-full notification
- Monitors bag space and offers a **Delete Grey Items** button when your bags reach the configured fullness threshold.
- Defaults to **90% bag usage**; change the threshold using a slash command.
- Only offers junk cleanup when grey-quality items are available.
- Keeps the button available while there are eligible grey items to clear.

### Controlled grey-item deletion
- Click the popup button to remove grey-quality junk from your bags.
- Handles multiple eligible items through the addon's deletion flow; follow any additional on-screen prompts if shown.
- Skips locked items and avoids attempting deletion while another item is held on the cursor.
- Designed for **manual, on-demand cleanup**, rather than silently deleting your items in the background.

**Warning:** Deleted items are destroyed, not sold to a vendor. Check your bags before confirming cleanup.

### Optional Warlock Soul Shard cleanup
- **Right-click the minimap icon** to show or hide the separate Soul Shard cleanup button.
- Shows the number of Soul Shards detected in your bags.
- Deletes **one Soul Shard per click** and reports the remaining count in chat.
- Hides the cleanup control when no Soul Shards remain.
- The Soul Shard feature applies to clients that use the classic Soul Shard item (item ID 6265).

### Combat and battleground safeguards
- Hides or disables deletion controls while in combat.
- Pauses cleanup controls in battlegrounds and restores operation after leaving when safe.
- Avoids protected actions during restricted gameplay states.

### Minimap controls and saved settings
- Minimap launcher for addon controls, including the Soul Shard shortcut.
- Hide, show, lock, unlock, or reset the minimap icon.
- Move the cleanup buttons and retain their positions between sessions.
- Pause or resume the addon whenever needed.

### Localization
Includes translations for **English, German, French, Spanish (Spain and Mexico), Italian, Brazilian Portuguese, Russian, Korean, Simplified Chinese, and Traditional Chinese**.

Supported locale codes: `enUS`, `deDE`, `frFR`, `esES`, `esMX`, `itIT`, `ptBR`, `ruRU`, `koKR`, `zhCN`, `zhTW`.

## Getting started

1. Install AutoJunkDestroyer in your client's `Interface/AddOns/` folder.
2. Log in or type `/reload` if updating an installed copy.
3. Keep the default **90%** bag threshold or set your preferred threshold with `/ajd threshold 90`.
4. When your bags fill up and grey items are available, use the **Delete Grey Items** button.
5. If you play a Warlock on a client with classic Soul Shards, right-click the minimap icon to access shard cleanup.

## Slash commands

| Command | What it does |
| --- | --- |
| `/ajd` | Display addon help / available commands |
| `/ajd threshold 90` | Set the bag-full trigger to 90% |
| `/ajd threshold 0.90` | Alternative format for the same threshold |
| `/ajd pause` | Pause automatic popup behavior |
| `/ajd resume` | Resume addon operation |
| `/ajd toggle` | Toggle the junk deletion popup |
| `/ajd minimap hide` | Hide the minimap icon |
| `/ajd minimap show` | Show the minimap icon |
| `/ajd minimap lock` | Lock the minimap icon in place |
| `/ajd minimap unlock` | Allow minimap icon movement |
| `/ajd minimap reset` | Reset the minimap icon position |

## Client compatibility

Version 1.3.0 adds **WoW Forever 1.60.1** compatibility, including container API handling and additional item deletion safeguards. The package also retains its existing Classic Era and TBC Anniversary support files.

Install into the `Interface/AddOns/` directory of the **specific game client** you use. For example:

- **Classic Era:** `World of Warcraft/_classic_era_/Interface/AddOns/` (or your installation's Classic directory)
- **TBC Anniversary:** the corresponding Classic client's `Interface/AddOns/` directory
- **WoW Forever:** your WoW Forever installation's `Interface/AddOns/` directory

If your game lists the addon as out of date, first confirm that you installed the correct client version of the addon.

## Frequently asked questions

**Does AutoJunkDestroyer sell grey items?**  
No. It destroys eligible grey items when you use the deletion control. Visit a vendor instead if you want the sale value.

**Will it delete green, blue, or epic gear?**  
The junk cleanup feature targets grey-quality items, not higher-quality equipment.

**Why isn't the cleanup button showing?**  
Check that you have grey items, that your bags meet the threshold, and that the addon is not paused or temporarily disabled in combat or a battleground.

**How do I open Soul Shard cleanup?**  
Right-click the minimap icon. The feature requires the classic Soul Shard item to exist in the client and your bags.

## Included libraries

The addon bundles the libraries it needs, including AceDB-3.0, AceLocale-3.0, LibDataBroker-1.1, and LibDBIcon-1.0.

## Feedback and support

Find the addon on [CurseForge](https://www.curseforge.com/wow/addons/auto-junk-destroyer). When reporting a bug, include your game client/version, the steps to reproduce it, and any Lua error text.

**Maintained by Milestorme.**
