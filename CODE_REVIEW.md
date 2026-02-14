# AutoJunkDestroyer Code Review

Date: 2026-02-14

## Scope
- `AutoJunkDestroyer.lua`
- `Locales/enUS.lua` plus locale parity spot checks
- `README.md`
- `AutoJunkDestroyer-Classic.toc`, `AutoJunkDestroyer-TBC.toc`

---

## Executive summary
The addon is generally solid: defensive state handling around battleground/combat transitions is clear, bag-refresh debouncing is sensible, and the AceDB data separation plus migration hardening is a strong stability improvement. The highest-value follow-up items are mostly polish and consistency fixes (command/docs drift, localization consistency, and reducing long-file complexity).

---

## Findings and recommendations

## 1) Command/documentation drift: `/ajd resume` is documented but not implemented
**Severity:** Medium  
**Impact:** User confusion and support churn.

### Evidence
- README documents `/ajd pause` and `/ajd resume`.  
- Slash command parser only handles `pause` (toggle), not `resume`.

### Recommendation
- Add explicit command handling for `resume` (and optionally `status`) so docs and behavior match.
- Alternatively, update README to reflect that `/ajd pause` toggles both states.

---

## 2) Some user-facing strings bypass localization
**Severity:** Low-Medium  
**Impact:** Incomplete localization experience for non-English users.

### Evidence
- Several chat outputs are hardcoded English debug/status strings (e.g., popup position and minimap status printouts) rather than locale keys.

### Recommendation
- Move remaining hardcoded `Print("...")` strings into locale keys and reuse `L[...]` for all user-visible text.

---

## 3) Single-file complexity is high; split into modules
**Severity:** Medium (maintainability)  
**Impact:** Harder future changes, higher regression risk.

### Evidence
- `AutoJunkDestroyer.lua` currently combines event routing, UI, deletion logic, AceDB migration/hardening, slash commands, and shard utilities.

### Recommendation
- Split into focused files (e.g., `Core.lua`, `UI.lua`, `Commands.lua`, `Shard.lua`, `Minimap.lua`, `Migration.lua`).
- Keep startup wiring in one entrypoint file.

---

## 4) AceDB wrapper approach is effective but high-risk if upstream internals change
**Severity:** Medium  
**Impact:** Potential compatibility risk with future AceDB internals.

### Evidence
- The code wraps `AceDB.frame`'s `OnEvent` to sanitize DB state before logout.

### Recommendation
- Keep this guard, but add an in-code note about AceDB version expectations and a safety no-op path if frame/script shapes change.
- Add lightweight self-check logging only in debug mode.

---

## 5) Add automated static checks in CI (syntax + locale key parity)
**Severity:** Medium (quality process)  
**Impact:** Prevents accidental breakage before release.

### Evidence
- Project currently relies on manual validation; locale correctness is important and easy to regress.

### Recommendation
- Add a simple CI job to run:
  - Lua syntax check for addon source files.
  - Locale key parity verification against `Locales/enUS.lua`.
- Keep checks lightweight to match addon repo simplicity.

---

## 6) Small correctness/polish opportunities
**Severity:** Low

### Observations
- `Print()` uses `(L["ADDON_NAME"] or L["ADDON_NAME"])`, which is redundant.
- Inline comments mention some older event names while code registers `BAG_UPDATE_DELAYED`.

### Recommendation
- Clean tiny redundancies/comments during next maintenance pass.

---

## What is already strong
- Good combat/BG gating and deferred re-enable behavior.
- Debounced bag refresh strategy.
- Sensible SavedVariables clamping/defaults.
- Dedicated `AutoJunkDestroyerIconDB` and migration cleanup around AceDB shape corruption.

---

## Suggested roadmap (minimal risk)
1. Align slash commands and README (`resume` + optional `status`).
2. Finish localization sweep for remaining hardcoded chat strings.
3. Add lightweight CI checks for syntax and locale parity.
4. Incremental modular split of `AutoJunkDestroyer.lua` with no feature changes.
