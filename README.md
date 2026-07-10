# EZOMetter

EZOMetter is a beta ESO addon in the EZO family focused on practical combat visibility for PvE players, especially DD-oriented self checks and target-state tracking.

## Status

Public beta. The addon is usable, but combat APIs and derived statistics are still being validated in real encounters. Reports should be treated as helper data, not as a replacement for full combat log analysis.

## Requirements

- The Elder Scrolls Online current live client.
- `LibAddonMenu-2.0` is required for settings.
- Optional libraries:
  - `LibCombat` enables observed damage/healing panels and damage-weighted summaries.
  - `LibChatMessage`, `LibDebugLogger`, and `DebugLogViewer` improve chat/debug output.

## Installation

1. Download or clone the repository.
2. Copy the `EZOMetter` folder into:

```text
Documents/Elder Scrolls Online/live/AddOns/
```

3. Enable `EZOMetter` and required libraries from the ESO Add-Ons screen.
4. Configure panels from Settings > Addons > EZOMetter.

For development builds, the package script creates `dist/EZOMetter_v0.1.18.zip`.

## Main Features

- Movable HUD alerts for missing role/self buffs.
- Separate Off Balance tracker with real uptime and cooldown/cycle reporting.
- Exploiter CP detection and estimated value from damage done during real Off Balance.
- Coral Riptide bonus panel and last-combat summary.
- DD stats panel for damage, critical chance, penetration, and critical damage with own/effective/max calculated values.
- Observed DPS/HPS panels through optional `LibCombat`.
- Fatecarver channel timing helper.
- One optional informational report after combat.

## Safety Limits

- The addon does not automate combat, rotations, inputs, movement, targeting, or keybinds.
- HUD controls are intended to appear only in normal HUD/HUD UI scenes.
- Group damage/healing values are client-observed and depend on events received by the local client.
- Exploiter value is estimated; ESO does not expose a separate native event for damage added by that CP star.
- Discord publication scripts are present for project workflows, but they must not be run without explicit authorization.

## Test Notes

Before publishing a beta build, run:

```powershell
.\tools\bump-version.ps1 -Check
git diff --check
pwsh -NoProfile -File .\scripts\ezo\build-addon-package.ps1 -Force
```

Recommended in-game checks:

- `/reloadui` with all panels locked and unlocked.
- HUD visibility in combat, out of combat, menus, map, crafting, Champion Points, and Tales of Tribute.
- Dummy parse with and without Off Balance/Exploiter.
- DD role buff alerts, Coral Riptide equipped/not equipped, and Fatecarver channel behavior.
- `LibCombat` installed and missing.
