# Changelog


## 1.2.0
### Added
- Added explicit `/ajd resume` and `/ajd status` slash commands.
- Added localized slash-command aliases for core and minimap subcommands across non-English locales.
- Added dedicated `Commands.lua` module to separate slash routing from core logic.
- Added CI workflow and scripts for Lua syntax checks and locale key parity.

### Changed
- Localized remaining hardcoded slash-command output strings (popup position, minimap position, and help text).
- Translated newly added slash/minimap/popup status keys into each locale language (instead of English placeholders).
- Improved AceDB pre-logout wrapping notes/guards for forward compatibility diagnostics.
- Updated README slash command docs for pause/resume/status behavior.

### Fixed
- Cleaned minor code/comment polish issues (`Print` addon-name redundancy and event comment naming).


## 1.1.10
### Fixed
- Consolidated SavedVariables initialization so shard button defaults are always set alongside the bag threshold.

## 1.1.9
### AceDB SavedVariables Hardening & Migration Fix

### Fixed
- Fixed a persistent logout error:
  - `AceDB-3.0.lua:369 bad argument #1 to 'next' (table expected, got boolean)`
- Resolved corrupted AceDB SavedVariables where non-table values (e.g. `_setupComplete = true`) were stored directly inside the `profile` section.
- Prevented AceDB from encountering invalid `next(boolean)` calls during `PLAYER_LOGOUT`.

### Added
- One-time SavedVariables migration and cleanup:
  - Converts legacy flat `profile` tables into proper AceDB format (`profileName → table`)
  - Preserves valid minimap settings used by LibDBIcon
  - Moves legacy/invalid keys into a backup table for safety
- Permanent runtime hardening:
  - Sanitizes AceDB profile data right before logout to prevent future corruption
  - Ensures only table values exist inside AceDB profile sections

### Notes
- Migration runs **once only** and will not repeat on future logins.
- No AceDB library files were modified.
- Existing settings are preserved where valid.

## 1.1.8
### Fixed
- Fixed an issue where the **Soul Shard delete popup displayed no text** when opened via minimap right-click.
- Ensured Soul Shard UI text is **refreshed immediately on show**, instead of waiting for later events (e.g. combat or bag updates).
- Added **missing localization keys** for Soul Shard UI labels and messages.
- Audited all locale files to ensure **complete key coverage** with proper English fallback.

- Fixed Soul Shard popup text being hidden when the grey-item delete popup was visible.
- Corrected frame layering so both popups render correctly without obscuring text.

- Adjusted popup anchoring and layout so both buttons can coexist cleanly.

- Fixed a **logout error caused by AceDB receiving a boolean instead of a table**.
- Separated AceDB minimap data into its own SavedVariables table to avoid structure conflicts.
- Added safe migration for existing minimap icon settings.
- Prevented `PLAYER_LOGOUT` errors without modifying AceDB itself.

## 1.1.7
- Added Icon and updated toc

## 1.1.6
- Version bump for CurseForge release
- Added TOC locale metadata (`X-Localizations`) for CF auto-detection
- No code logic changes (documentation + metadata release only)

## 1.1.5
- Full localization pass (all major languages)
- Enforced 1:1 locale key parity with enUS
- Normalized tooltip text widths across locales
- Added README and CurseForge documentation
- Fixed Lua structural error causing EOF parse failure

## 1.1.4
- Embedded updated Ace3 libraries
- Embedded updated LibDataBroker & LibDBIcon
- Removed remaining English-only strings
- Improved locale fallback safety

## 1.1.3
- Stable shard deletion utility
- Combat-safe popup logic
- Persistent UI state
