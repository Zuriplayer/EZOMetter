# EZOMetter

Combat visibility HUD for *The Elder Scrolls Online*, focused on role self-checks, DD-oriented target state tracking, and lightweight post-combat summaries.

¿Prefieres español? Lee el [README en español](README.es.md).

For support, bug reports, and suggestions, join Discord: https://discord.gg/hV4nxtfP3a


## Status

EZOMetter is in public beta. The addon is usable, but several combat metrics depend on ESO client events, visible target state, and optional libraries. Treat the numbers as practical helper information, not as a full replacement for dedicated combat log analysis.

Current version: **0.1.18**.

## Requirements

- *The Elder Scrolls Online* for PC.
- [LibAddonMenu-2.0](https://www.esoui.com/downloads/info7-LibAddonMenu.html) is required for the settings panel.
- Optional libraries:
  - `LibCombat` enables observed damage/healing panels, damage-weighted DD stat summaries, and Off Balance damage attribution.
  - `LibChatMessage` improves addon chat output.
  - `LibDebugLogger` and `DebugLogViewer` are used for technical debug logs and the optional post-combat report output.

## Installation

1. Clone this repository, or use a published ZIP package when one is available.
2. Copy the `EZOMetter` folder into your ESO AddOns folder:

```text
Documents/Elder Scrolls Online/live/AddOns/
```

3. Install and enable `LibAddonMenu-2.0`.
4. Enable `EZOMetter` from the in-game Add-Ons screen.
5. Configure the addon from Settings > Addons > EZOMetter.

## Main Features

### General Settings

- English and Spanish localization, with automatic client-language detection or manual language selection.
- Manual role profile selection for DD, Healer, or Tank.
- Optional automatic role detection based on equipped weapons and slotted skills. It uses conservative tank/healer scoring and falls back to DD.
- One global HUD unlock option that shows movable EZOMetter panels in normal HUD/HUD UI scenes.
- Optional post-combat report with date, character, content type, zone, boss/trash context, difficulty when available, and sections from active trackers.
- Debug mode for technical output through `LibDebugLogger`/`DebugLogViewer` when installed.

### Role Buff Alerts

- Movable alert for missing required self buffs for the selected role.
- DD currently checks Major Brutality, Major Sorcery, Major Savagery, Major Prophecy, and Banner Bearer when a Banner skill is slotted.
- Healer currently checks Major Sorcery and Major Prophecy.
- Tank currently has no required self-buff list.
- Configurable alert background opacity and border.
- The alert records last-combat uptime for required checks when combat reporting is enabled.

### Off Balance Tracker

- Separate movable Off Balance HUD for the current target or tracked boss.
- Tracks real Off Balance separately from the estimated Off Balance cooldown/cycle.
- Boss focus can keep tracking known boss state when you briefly look away.
- Optional boss-only and combat-only visibility.
- Configurable background opacity, border, and colors for ready, active, and cooldown states.
- Optional pulse when Off Balance starts.
- Debug scan for current target buffs and Off Balance events.
- Detects the Exploiter Champion Point star when available, checks whether it is slotted, reads points spent, and estimates its value from damage done during real Off Balance.
- The Exploiter estimate is damage-based; ESO does not expose a separate native event for "damage added by Exploiter".

### Coral Riptide Tracker

- Separate movable Coral Riptide panel.
- Detects worn Coral Riptide or Perfected Coral Riptide pieces by set name matching and treats the bonus as active at 5 pieces.
- Estimates the damage bonus from missing stamina, up to +600 at or below 50% stamina.
- Shows state bands for cap, OK, medium, low, bad, and inactive.
- Configurable size, background opacity, border, DD-only visibility, and combat-only visibility.
- Optional equipment debug scan for set names and IDs.
- Last-combat summary includes estimated average bonus and time in useful/bad/inactive bands.

### DD Stats

- Separate movable DD stats panel for:
  - highest Weapon/Spell Damage,
  - Critical Chance,
  - Penetration,
  - Critical Damage.
- Shows own, effective, and max calculated values where applicable.
- Effective penetration and critical damage include supported assumptions and detected target debuffs.
- Configurable thresholds for offensive damage, critical chance, self penetration, critical damage, target resistance, Crusher, Alkosh, and Tremorscale.
- Configurable background opacity, border, DD-only visibility, and combat-only visibility.
- Last-combat tooltip/report includes time-based and damage-weighted summaries when data is available.

### Observed Damage and Healing

- Optional `LibCombat` panels for observed outgoing damage and healing.
- Observed Damage shows current DPS, average DPS, observed group share, and boss damage/share when available.
- Observed Healing shows current HPS, average HPS, and observed group healing share when available.
- Both panels support combat-only visibility, background opacity, border, and role-based visibility.
- Group totals are client-observed values and depend on events received by the local client.

### Fatecarver Helper

- Horizontal Fatecarver channel bar for Arcanist Fatecarver, Exhausting Fatecarver, and Pragmatic Fatecarver.
- Detects Fatecarver on either action bar.
- Tracks active channel timing from combat events and player effects.
- Configurable cancel-window warning in milliseconds, background opacity, and border.
- Last-combat summary reports casts, completed channels, OK cancels, early stops, and early-stop timing.

## Safety Limits

- EZOMetter does not automate combat, rotations, ability use, movement, targeting, blocking, equipment changes, Champion Point changes, or keybinds.
- It does not intercept global input.
- It does not replace vanilla UI elements.
- HUD elements are designed to appear only in normal HUD/HUD UI scenes and not in menus such as inventory, map, crafting, Champion Points, or Tales of Tribute.
- Observed group damage/healing and Exploiter value are estimates based on events available to the client.
- The addon includes Discord publication scripts for project maintenance, but nothing is posted to Discord without explicit authorization.

## Recommended Testing

Before committing code changes:

```powershell
.\tools\bump-version.ps1 -Check
git diff --check
```

Recommended in-game checks:

- `/reloadui` with panels locked and unlocked.
- Settings panel opens through LibAddonMenu.
- English/Spanish language selection and automatic language mode.
- HUD visibility in combat, out of combat, inventory, map, crafting, Champion Points, Tales of Tribute, and addon settings.
- DD role buff alerts with and without required buffs.
- Banner Bearer alert when a Banner skill is slotted and when no Banner skill is slotted.
- Off Balance on dummy/boss, including real active time, cooldown/cycle, and Exploiter reporting.
- Coral Riptide with fewer than 5 pieces, 5 pieces, and different stamina levels.
- DD Stats own/effective/max values and tooltip after combat.
- Observed Damage/Healing with `LibCombat` installed and with `LibCombat` missing.
- Fatecarver channel start, completion, early stop, and warning color.

## Reporting Issues

Please include:

- EZOMetter version.
- ESO client language.
- Installed optional libraries.
- Character role/profile.
- Steps to reproduce the issue.
- Screenshots or DebugLogViewer output when relevant.

Support, bug reports, and suggestions: https://discord.gg/hV4nxtfP3a

## License

MIT. See [LICENSE](LICENSE).

Developed and maintained by Zuriplayer.
