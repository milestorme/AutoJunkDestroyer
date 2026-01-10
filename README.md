# AutoJunkDestroyer

**AutoJunkDestroyer** is a lightweight World of Warcraft addon that helps you safely and efficiently delete grey (poor-quality) items when your bags are nearly full — without interfering with combat, battlegrounds, or normal gameplay.

Designed for **WoW Classic Era**, with robust handling for combat lockdowns, zoning, reloads, and edge-case Blizzard API behavior.

---

## ✨ Features

- 🧹 **Automatic grey item popup**
  - Appears when bag usage reaches **90% or higher**
  - Only shows if grey items are present
  - Stays visible while greys remain (even if usage drops slightly)

- 🖱 **Manual popup control**
  - Manually show or hide the popup at any time
  - When manually shown, the popup stays visible until **all grey items are deleted**
  - Manual hide is temporary — auto popup will return later when conditions are met

- ⚔ **Combat-safe**
  - Popup automatically hides when entering combat
  - Reappears after combat ends *only if* bag conditions are still met
  - No protected action errors or taint issues

- 🏟 **Battleground & instance safe**
  - Fully disabled while inside battlegrounds
  - Handles instance/raid zoning correctly
  - No false popups on zone transitions or loading screens

- 🔁 **Reload & zone-change resilient**
  - Prevents false popups caused by transient bag API data
  - Delayed checks ensure bag data is stable before triggering

- 💾 **Persistent UI state**
  - Popup position is saved across reloads and logouts
  - Manual popup state is remembered correctly
  - Minimap button position is saved

- 🧠 **Smart suppression logic**
  - If you manually hide the popup while above 90%, it stays hidden
  - Auto popup re-enables automatically once bag usage drops below 90% and later reaches it again

---

## 🔮 Soul Shard Deletion (Warlock Utility)

AutoJunkDestroyer also includes an **optional Soul Shard cleanup tool** for Warlocks.

- 🟣 **Right-click the minimap icon** to toggle a movable button:
  - **“Delete Soul Shards (N)”**
- Deletes **one Soul Shard per click** (item ID 6265)
- **Fully Blizzard-safe**
  - No auto-delete loops
  - No protected actions
  - One click = one delete
- ⚔ **Combat / battleground safe**
  - Disabled during combat or in battlegrounds
- 💬 **Clear chat feedback**
  - Prints confirmation after each delete
  - Shows **remaining Soul Shard count**, synced with bag updates
- 🧲 **Movable & persistent**
  - Drag to reposition
  - Position is saved across reloads and logouts
- 🔁 **Live updates**
  - Button count updates immediately as shards are deleted

> This feature is completely independent of grey item deletion and never triggers automatically.

---

## 🔧 Commands

| Command | Description |
|------|------------|
| `/ajd` | Toggle the popup manually |
| `/ajd pause` | Pause the addon |
| `/ajd resume` | Resume the addon |
| `/ajd bags` | Print current bag usage percentage |
| `/ajd minimap hide` | Hide minimap button |
| `/ajd minimap show` | Show minimap button |

---

## 🖱 Popup Behavior Summary

| Situation | Popup Behavior |
|---------|----------------|
| Bags < 90% | Hidden |
| Bags ≥ 90% + greys | Auto shows |
| Delete 1 grey | Stays visible |
| All greys gone | Hides |
| Enter combat | Hides |
| Leave combat (still ≥ 90%) | Reappears |
| Manual hide | Suppressed until conditions reset |
| Reload / zone change | No false popup |

---

## 📦 Installation

https://www.curseforge.com/wow/addons/auto-junk-destroyer



