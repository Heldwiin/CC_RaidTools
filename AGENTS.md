# CC RaidTools — Instructions for AI Agents

## Project overview

CC RaidTools is a World of Warcraft Retail addon developed for the guild **Caelestis Concilium (CC)**.

Target client: **WoW Retail 12.1**.

The addon is intentionally lightweight and modular, with no external library dependency.

## Repository structure

Core:
- `CC_RaidTools.lua` — addon core, SavedVariables, `/ccrt`, main configuration window and shared UI helpers.

Gameplay modules:
- `AutoPromote.lua` — automatic raid-assistant promotion.
- `AutoLog.lua` — automatic combat logging for configured raid/dungeon difficulties.
- `ReadyCheck.lua` — custom Ready Check display, readiness state and raid buff/consumable checks.
- `InviteTool.lua` — whisper keyword invitation system.
- `Focus.lua` — mouse-button focus helper using secure actions.
- `MarksBar.lua` — raid target markers and world markers.

UI/branding:
- `GuildBranding.lua` — Caelestis Concilium watermark.
- `ModuleIcons.lua` — module icons in the `/ccrt` menu.

Do not create duplicate `*Fix.lua` or compatibility modules unless there is a clear technical reason and the user explicitly accepts the additional file.

## General coding rules

- Preserve the existing architecture and visual identity.
- Prefer small, targeted fixes over unrelated refactoring.
- Preserve existing behavior unless the user explicitly requests a behavior change.
- Do not introduce external libraries without explicit approval.
- Keep Lua readable and defensive.
- Initialize optional tables and settings before indexing them.
- Never overwrite an existing SavedVariable value just to establish a default.
- When adding a SavedVariable, only assign the default when the value is `nil`.

## SavedVariables

The addon uses one main SavedVariable:

`AutoPromoteDB`

Existing settings include, among others:
- `names`
- `ranks`
- `rankNames`
- `windowPos`
- `focus`
- `marksBar`
- `logging`
- `raidCheckEnabled`

When adding settings:
1. Initialize the parent table defensively.
2. Preserve all existing user values.
3. Set defaults only when individual values are `nil`.
4. Consider migration/compatibility for users upgrading from older releases.

## WoW combat and protected API rules

This addon runs on WoW Retail and must respect Blizzard's secure execution model.

Be especially careful with:
- `SetRaidTarget()`
- `ClearRaidMarker()`
- protected unit/raid marker functions
- secure action buttons
- secure attributes
- changing protected frames during combat

Never call protected functions directly from ordinary addon code when the action is expected to work in combat.

For actions that must be available during combat, use Blizzard's secure action mechanisms (`SecureActionButtonTemplate`) and preconfigure secure attributes outside combat.

Never reposition, resize, show/hide, or otherwise modify secure action buttons during combat if the operation is protected. Defer layout/configuration changes until `PLAYER_REGEN_ENABLED`.

Avoid introducing taint into Blizzard frames.

## Marks Bar

The Marks Bar contains two rows:
- raid target markers
- world markers

World marker mapping is fixed and must not be changed:

- `/wm 1` = square
- `/wm 2` = triangle
- `/wm 3` = diamond
- `/wm 4` = cross
- `/wm 5` = star
- `/wm 6` = circle
- `/wm 7` = moon
- `/wm 8` = skull/TDM

The visual order may be changed only when explicitly requested; the actual marker mapping must remain correct.

The bar supports:
- enable/disable
- locked/unlocked position
- horizontal/vertical orientation
- mouseover display
- saved position

Any layout change affecting secure buttons must be deferred outside combat.

## Ready Check

The custom Ready Check frame must be created with:

`BackdropTemplate`

The custom close button should be created directly by `ReadyCheck.lua`; do not rely on a delayed external skinning file for a frame that is created on demand.

The Ready Check refresh system must not run indefinitely after the window is closed.

If a ticker is used:
- keep its frequency reasonable;
- cancel it when the window closes/hides;
- restart it only when the window is shown;
- do not leave a permanent background ticker running.

Aura scanning can be expensive. Avoid repeatedly scanning unnecessary aura slots at very high frequency. Prefer event-driven refreshes (`UNIT_AURA`) and a modest fallback ticker when necessary.

Do not assume all aura values are readable; respect WoW secret/protected values.

## AutoLog

AutoLog supports:
- LFR
- Normal raid
- Heroic raid
- Mythic raid
- Mythic dungeon
- Mythic+

The addon must distinguish between:
1. combat logging started manually by the player;
2. combat logging started by CC RaidTools.

**Never stop combat logging that the player started manually.**

If CC RaidTools starts logging, its ownership state must survive `/reload` sufficiently to allow the addon to stop logging when leaving the relevant instance.

AutoLog settings must survive reloads and upgrades.

## Auto Promote

Promotion logic must always validate the current state before promoting:
- player is in a raid/group where promotion is applicable;
- player running CC RaidTools is still group/raid leader;
- target is still present;
- target is still eligible;
- target is not already assistant.

If promotion is deferred because of combat lockdown, do not blindly promote the stored names when combat ends. Re-run the normal validation/promotion logic.

Pending entries should be removed once handled.

## Focus

Focus uses secure mouse-button behavior.

Do not weaken secure handling in order to support arbitrary frames.

Any compatibility improvement for raid frames must be tested carefully because changes to secure click handling can cause `ADDON_ACTION_BLOCKED` or taint.

## UI and visual identity

Keep the established CC RaidTools visual style:
- dark/translucent panels;
- blue CC accent;
- subtle pixel borders;
- small WoW-style icons for modules;
- discreet Caelestis Concilium watermark.

The guild watermark is intentionally subtle. Do not replace it with a large opaque logo unless explicitly requested.

Do not redesign the whole configuration window for a small feature request.

## Module menu icons

Current visual intent:
- Auto Promote → group/leader crown icon.
- AutoLog → white parchment/log icon with writing.
- Ready Check → green ready-check tick.
- Invite Tool → group/invite icon.
- Focus → target icon.
- Marks Bar → raid marker icon.

Use actual WoW UI textures where possible rather than emoji or text glyphs.

## Commands

The addon intentionally exposes **one command only**:

`/ccrt` — opens the configuration window.

Do not add aliases, subcommands, debug commands, or undocumented slash commands unless the user explicitly requests them.

Keep README and in-game behavior synchronized with this rule.

## Versioning and releases

Version is stored in `CC_RaidTools.toc`.

When the user asks to prepare, bump, finalize, or release a new version, synchronize the version everywhere it is visibly or explicitly stored. At minimum:

1. Update `## Version:` in `CC_RaidTools.toc`.
2. Update the in-game loading message in `CC_RaidTools.lua` (for example `v1.1.10 chargé`).
3. `ReadyCheck.lua` uses the static title `CC RaidTools - Ready Check`; **do not add or remove a version number from this title during releases**.
4. Update the displayed version in `README.md` and its release/version section if present.
5. Add/update the corresponding entry in `CHANGELOG.md`.
6. Search the entire repository for the previous version string and update any remaining user-visible release/version references.
7. Before declaring the release ready, verify that the versioned files contain the same target version and that the Ready Check title remains static.

When only a bug fix is requested and no version bump is requested, do not silently increment the release version.

When preparing a release, do not change already-tested functional code merely to synchronize version strings. In particular, do not alter the Ready Check title for versioning; only change Ready Check code when a functional change is explicitly requested.

Do not create a GitHub Release unless explicitly requested.

Use the project's incremental versioning convention (`1.0.0`, `1.0.1`, `1.0.2`, etc.).

## Testing checklist

After significant changes, test the affected module and, when relevant:

1. `/reload`
2. `/ccrt`
3. opening the modified module
4. closing/reopening its window
5. SavedVariables persistence after `/reload`
6. behavior inside combat
7. behavior after leaving combat
8. protected-action behavior
9. fresh installation/upgrade behavior

For Ready Check specifically:
- start a real Ready Check;
- verify the custom window appears;
- verify the counter updates;
- test both raid and 5-player group modes;
- verify group columns appear only for classes present;
- verify the window width adapts immediately after group composition changes;
- close it manually;
- verify no refresh ticker continues running;
- start another Ready Check.

For Marks Bar specifically:
- test raid markers;
- test world markers and their mapping;
- test orientation changes;
- test locked position;
- test mouseover mode;
- test configuration changes during combat.

For AutoLog specifically:
- test each configured difficulty;
- verify the chat message when logging starts/stops;
- verify manually started logging is never stopped by the addon;
- test `/reload` while logging is active.

## Debugging principles

When a Lua error is reported:
1. Identify the exact failing file and line.
2. Inspect the current repository version before changing code.
3. Fix the root cause rather than masking the error.
4. Avoid creating another module solely to patch a previous module unless necessary.
5. Check for combat-lockdown/taint implications.
6. Check SavedVariables compatibility.
7. Keep the fix as localized as practical.

## Important project history

Previous bugs have included:
- calling protected raid-marker functions directly;
- secure-frame changes during combat;
- missing `BackdropTemplate` on frames using `SetBackdrop`;
- Ready Check ticker continuing after the window was closed;
- SavedVariable tables being absent on some installations;
- AutoLog ownership state being lost after `/reload`;
- incorrect world-marker mapping;
- creating separate `*Fix.lua` files that were not properly loaded by the TOC.

Treat these as known failure modes and avoid reintroducing them.

## Final rule

When uncertain, prefer:

**existing behavior + minimal change + defensive initialization + Blizzard-secure APIs + explicit testing**

over a large rewrite.
