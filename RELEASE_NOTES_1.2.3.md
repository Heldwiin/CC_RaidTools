# CC RaidTools v1.2.3

## Core / Architecture
- UI hooks centralized in the Core instead of module-specific ToggleUI monkey patches.
- SavedVariables migration from AutoPromoteDB to CCRaidToolsDB with backward compatibility.

## Raid Inspect
- More reliable inspection result association and gem/enchant detection.
- Roster changes during inspection are handled safely.

## Marks Bar
- Mouseover updates throttled to 30 ms and handled directly by the MarksBar module.
- Removed the temporary standalone MarksBarPerformance module.

## AutoLog / Focus / Invite Tool
- Session-only AutoLog ownership state.
- Safer Focus attribute restoration.
- Native Blizzard invite/suggest-invite path retained.

## Interface
- Version displayed in /ccrt and sourced from the TOC.
- Removed the addon welcome message from chat.
