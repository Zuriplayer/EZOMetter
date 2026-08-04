# EZOMetter

Combat visibility HUD for *The Elder Scrolls Online*, focused on role self-checks, DD-oriented target state tracking, and lightweight post-combat summaries.

¿Prefieres español? Lee el [README en español](README.es.md).

For support, bug reports, and suggestions, join Discord: https://discord.gg/ekw8zUAcRm


## Status

EZOMetter is in public beta. The addon is usable, but several combat metrics depend on ESO client events, visible target state, and optional libraries. Treat the numbers as practical helper information, not as a full replacement for dedicated combat log analysis.

Current version: **0.1.59**.

## Requirements

- *The Elder Scrolls Online* for PC.
- [LibAddonMenu-2.0](https://www.esoui.com/downloads/info7-LibAddonMenu.html) is required for the settings panel.
- Optional libraries:
  - `LibCombat` enables observed damage/healing panels, damage-weighted DD stat summaries, Off Balance damage attribution, and preferred Z'en stack tracking.
  - `LibChatMessage` improves addon chat output.
  - `LibDebugLogger` and `DebugLogViewer` are used for technical debug logs and the optional post-combat report output.
  - `EZOCore` provides central access through Settings > EZO and shared interface layout control.

## Installation

1. Clone this repository, or use a published ZIP package when one is available.
2. Copy the `EZOMetter` folder into your ESO AddOns folder.
3. Install and enable `LibAddonMenu-2.0`.
4. Enable `EZOMetter` from the in-game Add-Ons screen.
5. With EZOCore enabled, configure the addon from Settings > EZO > EZOMetter. Without EZOCore, use Settings > Addons > EZOMetter.

## Main Features

### General Settings

- English and Spanish localization, with automatic client-language detection or manual language selection.
- Manual role profile selection for DD, Healer, or Tank.
- Optional automatic role detection based on equipped weapons and slotted skills. It uses conservative tank/healer scoring and falls back to DD.
- One session-only global HUD unlock option that shows movable EZOMetter panels in normal HUD/HUD UI scenes. With EZOCore, the same aggregate surface participates in global or individual family layout control.
- Common HUD text size setting that scales EZOMetter visual windows and text together so panel layouts remain proportional.
- Shared HUD appearance controls for background opacity, border visibility, and border/accent color, applied consistently to every visual panel.
- Last-combat tooltips render above EZOMetter HUD panels, including the Custom Action Bars surface.
- Optional post-combat report with date, character, content type, zone, boss/trash context, difficulty when available, and one consolidated `Info` entry per combat. Every tracker has its own inclusion switch, enabled by default; disabled or irrelevant sections are omitted, and set trackers require their 5-piece bonus to have been available during the fight.
- Debug mode for technical output through `LibDebugLogger`/`DebugLogViewer` when installed.
- The settings panel uses purple information headers for section-level help, while each field keeps its own tooltip for specific behavior.

### Role Buff Alerts

- Movable alert for missing required self buffs for the selected role.
- DD currently checks Major Brutality, Major Sorcery, Major Savagery, Major Prophecy, and Banner Bearer when a Banner skill is slotted.
- Healer currently checks Major Sorcery and Major Prophecy.
- Tank currently has no required self-buff list.
- The alert records last-combat uptime for required checks when combat reporting is enabled.

### Off Balance Tracker

- Separate movable Off Balance HUD for the current target or tracked boss.
- Tracks real Off Balance separately from the estimated Off Balance cooldown/cycle.
- Keeps an explicit Off Balance title in the live panel, with the active/cooldown timer and current or last-combat counters beneath it.
- Boss focus can keep tracking known boss state when you briefly look away.
- Display mode selector can turn Off Balance off, show only the panel, show only the independent icon, or show both panel and icon.
- The panel has no visibility filters: whenever the panel surface is selected in the display mode, it is always shown.
- The floating icon has three icon-only filters that combine: show only in combat, show only on bosses, and show only while the Exploiter Champion Point star is slotted.
- The selected Off Balance surface follows the combat, boss, role-profile, and Exploiter CP filters. If combat-only and boss-only visibility are disabled, selected surfaces remain visible in the ready state outside combat.
- Configurable colors for ready, active, and cooldown states.
- Optional pulse when Off Balance starts.
- Debug scan for current target buffs and Off Balance events.
- Detects the Exploiter Champion Point star when available, checks whether it is slotted, reads points spent, and estimates its value from damage done during real Off Balance.
- The Exploiter estimate is damage-based; ESO does not expose a separate native event for "damage added by Exploiter".

### Coral Riptide Tracker

- Separate movable Coral Riptide panel.
- Detects worn Coral Riptide or Perfected Coral Riptide pieces by set name matching and treats the bonus as active at 5 pieces.
- Estimates the damage bonus from missing stamina, up to +600 at or below 50% stamina.
- Shows state bands for cap, OK, medium, low, bad, and inactive.
- Configurable size, DD-only visibility, and combat-only visibility.
- Optional equipment debug scan for set names and IDs.
- Last-combat summary includes estimated average bonus and time in useful/bad/inactive bands.

### Highland Sentinel Tracker

- Separate movable Highland Sentinel panel.
- Detects worn Highland Sentinel pieces by set name matching and treats the bonus as active at 5 pieces.
- Reads "Sentinel's Eye" stacks to calculate and display the real-time critical chance bonus.
- Configurable size, DD-only visibility, and combat-only visibility.
- Reports last-combat average stacks, estimated average critical bonus, active uptime, and maximum-stack uptime.
- Optional event debug log to verify stack events and ability IDs.

### Azureblight Reaper Tracker

- Separate movable Azureblight panel with the Blight Seed icon, raw stack count, remaining seconds, and duration bar.
- Reads Blight Seed (`abilityId 126631`) directly from the current reticle target and `boss1` through `boss6`.
- Keeps the observed debuff state across weapon swaps; the active bar never resets or hides a valid direct reading.
- Shows raw stacks without assuming a `/20` cap because the explosion threshold changes when more Azureblight wearers are present.
- Does not estimate missing stacks, attribute stacks to individual DoTs, or calculate Azureblight damage.
- Configurable size and combat-only visibility, plus a five-second preview and optional direct-event diagnostics.

### Roar of Alkosh Tracker

- Separate movable Roar of Alkosh panel, disabled by default.
- Detects equipped Roar of Alkosh through a canonical set itemLink read, with equipped-slot/name matching as fallback.
- Automatically hides below three equipped Roar of Alkosh pieces, while HUD layout editing and preview remain available.
- Tracks Alkosh by abilityId and uses the direct Line Breaker effect `beginTime`/`endTime` as the authoritative 10-second clock. The Trial Dummy aura is accepted only when ESO attributes it to the player.
- Keeps CombatMetrics penetration IDs as observed calculation signals; they cannot start or restart the cycle clock.
- Uses `EVENT_SYNERGY_ABILITY_CHANGED` and the current synergy-list API to observe every usable offer with its name and ability ID, with a current-prompt fallback on older API versions.
- Provides configurable activation-window start/end values. The progress bar shows directly observed remaining Line-Breaker time, drains to zero at expiry, and changes state between Wait, Window, Activate now, Late, and Expired.
- Correlates a proc with the recently removed primary synergy offer. Unmatched procs are reported explicitly as an unknown synergy instead of inventing a type.
- Counts, per combat and per synergy type, offers, activations inside/outside the configured window, and offers observed in the window that disappeared without a correlated proc.
- While the activation window is open, the live panel shows whether a usable synergy is currently available and the cumulative number of offers detected inside configured windows.
- Reports combat uptime as active Line-Breaker time divided by the complete combat time.
- Shows offer efficiency as actual active time divided by the internally simulated uptime supported by the usable synergies actually offered.
- Keeps the last valid combat metrics and per-type counts visible in the tooltip/report until new combat data replaces them.
- Provides Off, Monitor, and Cycle assistant modes. Cycle assistant is visual only and never intercepts or activates synergy input.
- Shows the independent activation alert in a red/orange warning style for the first combat synergy, offers inside the configured window, the first late offer when no synergy appeared during that window, and any usable offer after Line Breaker has expired.
- Optional direct-effect timing and synergy-offer debug logging.
- Last-combat tooltip/report includes actual uptime, offer efficiency, target/proc data, and the per-synergy breakdown.

### Z'en's Redress Tracker

- Separate movable Z'en panel for support DPS/healer setups.
- Auto mode shows the panel while wearing at least 3 pieces; On forces it visible for testing.
- Uses `LibCombat` as the preferred source for Z'en stacks when available, with an internal player-DoT counter as fallback.
- Counts your own damage-over-time effects on the tracked target as potential Z'en stacks, including fallback visibility below 5 set pieces.
- Tracks Touch of Z'en directly by abilityId and keeps its effective value for the detected Touch duration even if a weapon swap lowers the currently equipped Z'en piece count.
- Rejects ESO's `offline` pseudo-unit as a target name, prioritizes targets with active Touch/DoTs, and returns to the internal DoT counter as soon as LibCombat reports Touch faded.
- Shows pieces, potential stacks, effective value, Touch remaining time, target, stack source, and a stack bar.
- Optional debug event logging.
- Last-combat tooltip/report includes Touch uptime, potential/effective averages, cap time, and target data.

### DD Stats

- Separate movable DD stats panel for:
  - highest Weapon/Spell Damage,
  - Critical Chance,
  - Penetration,
  - Critical Damage.
- Own column shows live instant player stats; the Effective and Max Calc columns reflect your last combat. Without combat data yet, Effective mirrors Own and Max Calc stays empty.
- Effective penetration and critical damage include supported assumptions and detected target debuffs.
- Configurable thresholds for offensive damage, critical chance, self penetration, critical damage, target resistance, Crusher, Alkosh, and Tremorscale.
- Configurable DD-only visibility and combat-only visibility.
- Uses the first shared EZO multi-column window layout, with wider effective and maximum-value columns for readability.
- Last-combat tooltip/report includes time-based and damage-weighted summaries when data is available.

### Observed Damage and Healing

- Optional `LibCombat` panels for observed outgoing damage and healing.
- Observed Damage shows current DPS, average DPS, observed group share, and boss damage/share when available.
- Observed Healing shows current HPS, average HPS, and observed group healing share when available.
- Both panels support combat-only and role-based visibility.
- Group totals are client-observed values and depend on events received by the local client.

### Fatecarver Helper

- Its settings are grouped under a dedicated Fatecarver heading inside the Abilities submenu.
- Horizontal Fatecarver channel bar for Arcanist Fatecarver, Exhausting Fatecarver, and Pragmatic Fatecarver.
- Detects Fatecarver on either action bar.
- Tracks active channel timing from combat events and player effects.
- Configurable cancel-window warning in milliseconds.
- Last-combat summary reports casts, completed channels, OK cancels, early stops, and early-stop timing.

### Magma Fist Helper

- Its settings are grouped under a dedicated Magma Fist heading inside the Abilities submenu.
- Independent movable Magma Fist icon that remains visible in normal HUD scenes whenever Magma Fist is slotted, including outside combat, with a `0-3` Heat Shock stack badge.
- Reads the player's Heat Shock (`abilityId 134340`) stacks and expiration directly from effect events.
- A single centered countdown shows the directly observed remaining Heat Shock duration, so stack expiry is visible while building or holding the 3 stacks.
- Border legend: grey while below 3 stacks, amber whenever 3 stacks need to be maintained or used, green during the 6-second empowered-cast window, and red during the final 1.5 seconds of either Heat Shock or that window. The outer border uses a thicker high-visibility stroke.
- The public client data currently identifies Heat Shock and Magma Fist but not a separate 6-second player-buff ID. EZOMetter therefore derives the window from a deduplicated direct Heat Shock gained/updated event while the target was already observed at 3 stacks, and consumes it on the next observed Magma Fist impact or Heat Shock refresh.
- Direct Heat Shock expiry is used when present. If its effect event omits a usable `endTime`, the tracker retains that direct stack observation for the documented 7-second Heat Shock duration.
- Includes configurable icon size, HUD-layout positioning, a simulated preview, and optional event diagnostics.

## Safety Limits

- EZOMetter does not automate combat, rotations, ability use, movement, targeting, blocking, equipment changes, Champion Point changes, or keybinds.
- It does not intercept global input.
- It does not replace vanilla UI elements.
- HUD elements are designed to appear only in normal HUD/HUD UI scenes and not in menus such as inventory, map, crafting, Champion Points, or Tales of Tribute.
- Observed group damage/healing and Exploiter value are estimates based on events available to the client.
- The Magma Fist 6-second window is an event-derived alert until a dedicated player-effect ID can be confirmed from the live client; stacks and Heat Shock expiration remain direct readings.
- Alkosh Cycle assistant is advisory only; EZOMetter observes the available synergy list but does not block, consume, activate, or cancel synergy input.
- The addon includes Discord publication scripts for project maintenance, but nothing is posted to Discord without explicit authorization.

## Recommended Testing

Before committing code changes:

```powershell
.\tools\bump-version.ps1 -Check
git diff --check
```

Recommended in-game checks:

- `/reloadui` with panels locked and unlocked.
- Common HUD text size at minimum, default, and maximum values, checking that panels scale together with their text and remain movable.
- Settings panel opens under Settings > EZO when EZOCore is enabled, without a duplicate standard Addons entry.
- Standalone LibAddonMenu fallback opens when EZOCore is unavailable.
- Section-level and field-level help tooltips in the settings panel.
- English/Spanish language selection and automatic language mode.
- HUD visibility in combat, out of combat, inventory, map, crafting, Champion Points, Tales of Tribute, and addon settings.
- DD role buff alerts with and without required buffs.
- Banner Bearer alert when a Banner skill is slotted and when no Banner skill is slotted.
- Off Balance on dummy/boss, including real active time, cooldown/cycle, and Exploiter reporting.
- Coral Riptide with fewer than 5 pieces, 5 pieces, and different stamina levels.
- Azureblight Reaper on the front bar, back-bar DoTs ticking after both bar swaps, target changes, effect refreshes, and one or multiple set wearers.
- Roar of Alkosh with 0-2 pieces (hidden), 3-4 pieces (visible without the 5-piece bonus), 5 pieces, Monitor/Cycle modes, repeated updates of one proc, activations before/inside/after the window, an available synergy after expiry, offers lost in the window, Trial Dummy debuff, and a normal target when available.
- Z'en's Redress with 3-4 pieces, 5 pieces, multiple DoTs, Touch refreshes, target changes, weapon swaps, and with/without `LibCombat`.
- DD Stats own/effective/max values and tooltip after combat.
- Observed Damage/Healing with `LibCombat` installed and with `LibCombat` missing.
- Fatecarver channel start, completion, early stop, and warning color.
- Magma Fist casts 1-3 with the Heat Shock expiry countdown, the next max-stack hit opening the central 6-second countdown, the following cast consuming it, both expiry paths, target changes, and both weapon bars.

## Reporting Issues

Please include:

- EZOMetter version.
- ESO client language.
- Installed optional libraries.
- Character role/profile.
- Steps to reproduce the issue.
- Screenshots or DebugLogViewer output when relevant.

Support, bug reports, and suggestions: https://discord.gg/ekw8zUAcRm

## License

MIT. See [LICENSE](LICENSE).

Developed and maintained by Zuriplayer.
