# v3.3.7 - 2026-09-26

## Changes
- WoW Forever beta (interface 16001) fully supported alongside all existing flavors.
- Fixed: disabling now re-shows debuffs on visible nameplates in place, without a nameplate rebuild flash; hide no longer clears BuffFrame anchors.

# v3.3.7-beta.3 - 2026-09-25

## Changes
- Disabling no longer forces a full nameplate rebuild (removed the visible ~0.3s blink of all enemy plates); restore happens in place. /rnd test keeps the manual rebuild fallback.

# v3.3.7-beta.2 - 2026-09-25

## Changes
- Fixed: disabling the addon now re-shows debuffs on already-visible nameplates (forced nameplate rebuild after restore); hide no longer clears BuffFrame anchors.

# v3.3.7-beta.1 - 2026-09-25

## Changes
- Maintenance beta for the early-beta release cycle, built and verified against RGX-Framework v2.7.8.
- No functional changes since v3.3.6.

# v3.3.6 - 2026-09-19

## Changes
- Added Classic Era beta interface `16001` (WoW Forever, build 69913, project Camelot) to the TOC so the addon loads without the out-of-date flag.
- Fixed: Settings now survive SavedVariables loss. RND mirrors all settings into `RGXFrameworkDB` (RGX-Framework's SavedVariables) and restores them — with a visible chat warning — when `RNDSettings` comes back empty. Previously a settings loss silently re-enabled debuff removal because `enabled` defaults to `true`.

# v3.3.5 - 2026-09-17

## Changes
- Added verified WoW Forever Beta `1.60.1.69893` (Interface `120007`) compatibility.
- Enabling RND immediately hides debuffs on visible nameplates; disabling still restores them.
- Removed the raw `UNIT_AURA` listener because visible nameplate updates already handle the required refresh path.
- Synced the runtime version with the TOC metadata.

# v3.3.4 - 2026-08-22

## Changes
- Updated release metadata for the active supported client interfaces.

# v3.3.3 - 2026-08-07

## Changes
- TOC bump: Updated universal interface versions to 11509 (Classic Era), 20506 (TBC Anniversary), 50504 (MoP Classic), 120007 (Retail). Removed Cata (40402) and legacy Retail eras (110207, 120000, 120001).

# v3.3.2 - 2026-06-30

## Changes

- Updated for WoW Retail 12.0.7 (Interface 120007).

# v3.3.1 - 2026-04-29

## Documentation
- Added the v3.3.0 per-release changelog entry.
- Synced addon version metadata for the v3.3.1 documentation release.

# v3.3.0 - 2026-04-25

## Changes
- Migrated to RGX-Framework: minimap button now uses `RGXMinimap:Create()` â€” drag, angle persistence, tooltip, and show/hide handled by the framework.
- Migrated events and periodic timer to `RGX:RegisterEvent()` and `RGX:Every()`.
- Fixed: Minimap tooltip status now updates in real-time after left-clicking to toggle.
- Fixed: Disabling the addon (`/rnd off` or minimap click to disable) now correctly restores all previously hidden nameplate debuff/buff/aura frames. Previously frames stayed hidden permanently until a nameplate was refreshed.
- Added `## RequiredDeps: RGX-Framework` to TOC.
