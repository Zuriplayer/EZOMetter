# Changelog

## 0.1.59 - Magma Fist Stack Expiry Warning

- Keeps the max-stack alert active during the internal six-second bonus limit instead of returning the icon to a neutral state.
- Changes the timer, outer border, and stack badge to red during the final 1.5 seconds before the three Heat Shock stacks expire.

## 0.1.58 - Magma Fist Border Visibility

- Changes the active 6-second empowered-window color from orange to green while preserving red for the final 1.5 seconds.
- Doubles the outer alert-border thickness for better visibility.

## 0.1.57 - Larger Magma Fist Countdown

- Increases the centered Magma Fist countdown font for better readability.
- Documents the border-state legend: grey below 3 stacks, amber at 3, orange during the empowered window, and red during its final 1.5 seconds.

## 0.1.56 - Unified Magma Fist Countdown

- Uses one centered countdown for both Heat Shock expiry and the subsequent 6-second empowered-cast window.
- Removes the separate lower timer and exclamation mark; stack count and border color now identify the current phase without moving the countdown.

## 0.1.55 - Magma Fist Stack Expiry Timer

- Adds a small lower countdown for the directly observed Heat Shock expiry while stacks are active.
- Keeps the exclamation mark and central 6-second countdown reserved for the max-stack hit and the subsequent empowered-cast window, respectively.
- Clarifies that reaching 3 stacks alone does not start the empowered window; the additional hit must land before Heat Shock expires.

## 0.1.54 - Persistent Magma Fist Icon and Window Fix

- Keeps the Magma Fist icon visible in normal HUD scenes whenever the ability is slotted, including outside combat and below 3 Heat Shock stacks.
- Shows the currently observed `0-3` Heat Shock stack count in the icon badge.
- Opens the empowered window from a deduplicated direct gained/updated Heat Shock event at an already observed 3 stacks instead of requiring `endTime` to advance.
- Preserves direct effect expiry when ESO provides it and falls back to the documented 7-second Heat Shock duration when an effect event has no usable `endTime`.

## 0.1.53 - Ability Settings Grouping

- Split the Abilities settings into clearly labelled Fatecarver and Magma Fist groups, each with its own informational tooltip.
- Keeps the last-combat report option inside the Fatecarver group because Magma Fist currently provides an alert rather than a report section.

## 0.1.52 - Magma Fist Empowered-Cast Alert

- Added an independently movable Magma Fist icon that appears when the player's Heat Shock reaches 3 stacks.
- Uses an exclamation state for the max-stack hit that arms Magma Fist, then shows the 6-second countdown for the empowered next cast.
- Reads Heat Shock stacks and expiry directly from `abilityId 134340`; because no separate public 6-second buff ID is currently documented, the empowered window is derived only from a subsequent direct 3-stack refresh and is consumed by the next observed Magma Fist impact.
- Added configurable icon size, a positioning preview, and optional diagnostics for direct Heat Shock events, Magma Fist impacts, and candidate 6-second player effects.

## 0.1.51 - Direct Azureblight Reaper and Alkosh Timing

- Added a movable Azureblight Reaper panel that directly reads Blight Seed (`abilityId 126631`) stacks and remaining duration from the reticle target and boss unit tags.
- Keeps a valid observed seed visible across weapon swaps and does not gate the reading on the currently active weapon bar.
- Shows raw stacks without assuming a fixed 20-stack threshold and does not infer DoT ownership or Azureblight damage.
- Added configurable size, combat-only visibility, preview values for HUD positioning, and optional direct-event diagnostics.
- Raises last-combat summary tooltips above EZOMetter HUD panels so ability bars cannot cover their text.
- Makes Alkosh's directly observed Line-Breaker `beginTime`/`endTime` authoritative, so repeated effect updates and unrelated penetration IDs cannot restart the cycle bar.
- Changes the Alkosh bar to remaining duration, draining to zero on expiry, and restores the activation warning whenever a usable synergy is present without an active proc.
- Ignores duplicate combat-state notifications and only accepts scanned Trial Dummy timing effects when ESO attributes them to the player.

## 0.1.50 - Alkosh Warning and Z'en Weapon-Swap Persistence

- Changed the independent Alkosh activation alert from green confirmation styling to a red/orange warning treatment.
- Prompts for the first usable combat synergy and the first late synergy when no offer appeared inside the preceding activation window.
- Replaced the live possible-uptime value with offer efficiency and shows current synergy availability plus the cumulative in-window offer count while the activation window is open.
- Keeps Z'en effective stacks active after a weapon swap while the directly observed Touch of Z'en effect remains active.
- Prevents the Z'en tracker from selecting ESO's `offline` pseudo-unit and from retaining LibCombat's zero-stack fade value over subsequent fallback DoT reads.
- Adds per-tracker post-combat report switches while preserving one consolidated `Info` entry per combat.
- Omits disabled or irrelevant report sections; Coral, Highland, Alkosh, and Z'en require their 5-piece bonus to have been available during the fight.
- Adds Highland average stacks, estimated average bonus, active uptime, and maximum-stack uptime to the post-combat report.

## 0.1.49 - Alkosh synergy cycle assistant

- Added configurable Alkosh activation-window timing and a progress bar that fills toward the 10-second Line-Breaker expiry.
- Tracks usable synergy offers by name and ability ID, correlates activations with Alkosh procs, and reports in-window, outside-window, and lost-window counts per synergy type.
- Separates full-combat Alkosh uptime, achievable uptime from the synergies actually offered, and efficiency against that achievable time.
- Replaced the visual block-warning mode with a non-intercepting cycle assistant.
- Reduced the informational Alkosh panel and moved detailed synergy counts to its tooltip and post-combat report.
- Added an independently movable activation alert shown only when the configured window is open and a usable synergy is available, with alert-only size, opacity, and border settings.

## 0.1.48 - Off Balance tracking debug fix

- Fixed a Lua error (function expected instead of nil) caused by a missing `GetStateName` function in the Off Balance tracker when debug mode is enabled.

## 0.1.47 - Off Balance panel/icon visibility split

- The Off Balance panel no longer has combat, boss, or Exploiter filters: whenever the panel surface is selected in the display mode, it is always shown.
- Moved the combat, boss, and Exploiter visibility filters onto the floating icon as three icon-only options that combine: show only in combat, show only on bosses, and show only while the Exploiter Champion Point star is slotted.
- Removed the previous "hide icon in combat" option in favor of the clearer "icon: show only in combat".

## 0.1.46 - DD stats panel coherence and Off Balance icon combat visibility

- DD stats panel is now coherent per column: the Own column shows live instant player stats, while the Effective and Max Calc columns reflect your last combat. When there is no combat data yet, Effective mirrors Own and Max Calc stays empty.
- Added an Off Balance icon-only option, "Hide icon in combat", that hides the floating icon while you are in combat without affecting the panel.

## 0.1.45 - Off Balance Display Mode

- Replaced the Off Balance on/off checkbox with a display mode selector: Off, Panel, Icon, or Panel and icon.
- Kept the combat, boss, role, and Exploiter filters applying to whichever Off Balance surface is selected.

## 0.1.44 - Off Balance Icon Idle Visibility

- Fixed the independent Off Balance icon hiding while the tracker was otherwise allowed to show outside combat.
- Fixed Off Balance boolean settings for DD-only, boss focus, and active pulse so saved user choices are not reset to defaults on reload.

## 0.1.43 - Highland and Off Balance HUD polish

- Fixed an issue where the Highland Sentinel tracker panel could not be moved when the HUD was unlocked.
- Added active/cooldown labels and remaining time directly on the independent Off Balance icon.

## 0.1.42 - Highland Sentinel tracker

- Added a new tracker for the Highland Sentinel set. It detects when 5 pieces are equipped and tracks the "Sentinel's Eye" buff stacks to estimate the real-time critical chance bonus.

## 0.1.41 - Exploiter CP visibility option

- Added an option to the Off Balance tracker to automatically hide itself if the Exploiter Champion Point is not currently slotted.

## 0.1.40 - Adjustable Off Balance icon size

- Added a setting to LibAddonMenu to adjust the size of the independent Off Balance icon.

## 0.1.39 - Independent Off Balance icon

- Separated the Off Balance tracker's icon into its own independently movable window.
- The new standalone icon hides when the effect is not active or immune, reducing screen clutter out of combat.

## 0.1.38 - Fix empty combat readings and unavailable text

- Prevents brief empty combat sessions (with 0 data) from overriding the last valid reading when exiting combat.
- Replaces the "unavailable" text for the group metric with a simpler "--" dash.

## 0.1.37 - Compact layout for observed metrics

- Adds a compact layout option to the observed damage and healing trackers that hides row labels, centers the values, and removes the background and border.

## 0.1.36 - Fatecarver HUD move mode preview

- Ensures the Fatecarver meter displays a full backdrop, border, and preview bar/timer when HUD movement is unlocked.

## 0.1.35 - Shared HUD window appearance

- Moves HUD background opacity, border visibility, and border color to shared General settings.
- Applies the shared flat outline to every HUD panel and removes nested native tooltip frames.
- Makes the DD Stats left accent use the selected border color instead of an unintended white edge.
- Aligns Z'en movement with the shared drag helper so refreshes cannot enable free movement.
- Groups HUD text size with the shared HUD appearance controls and keeps post-combat reporting in General.
- Redesigns the Off Balance panel with a persistent title and an explicit out-of-combat state instead of an ambiguous "Ready" label.

## 0.1.34 - Alkosh panel visibility

- Hides the Alkosh HUD automatically below three equipped Roar of Alkosh pieces.
- Keeps the panel available during HUD layout editing and its built-in preview.

## 0.1.33 - DD Stats reference window

- Reworks the DD Stats panel as the first shared EZO window-style reference.
- Adds a reusable panel frame and fixed-column grid helper for future tracker migrations.
- Expands the DD Stats data columns and applies a subtle semantic accent while its border is enabled.

## 0.1.32 - Shared HUD text scaling

- Adds a common HUD text size setting for EZOMetter visual windows.
- Scales panel containers together with text so layouts stay proportional.
- Combines the shared scale with Coral Riptide's existing individual size setting.

## 0.1.31 - Z'en's Redress tracker MVP

- Adds a movable Z'en's Redress support-set panel with Off, Auto, and On modes.
- Counts player-applied damage-over-time effects as potential Z'en stacks even below 5 set pieces.
- Uses LibCombat as the preferred Z'en stack source when available, with the internal DoT counter as fallback.
- Tracks Touch of Z'en by abilityId and reports effective stacks only when the 5-piece Touch is active.
- Adds last-combat Z'en potential/effective averages, cap time, Touch uptime, and target reporting.

## 0.1.30 - Alkosh out-of-combat panel state

- Stops the live Alkosh panel from showing an aging proc timer and residual remaining time outside combat.

## 0.1.29 - Alkosh post-combat display

- Keeps the last valid Alkosh efficiency visible after combat instead of resetting the panel display to zero.

## 0.1.28 - Alkosh efficiency denominator

- Changes Alkosh `Up` to efficiency against observed possible uptime instead of total equipped combat time.
- Adds possible time to the Alkosh tooltip/report.

## 0.1.27 - Alkosh timer decay

- Prevents target aura scans with missing end times from refreshing Alkosh `Left` back to 10 seconds.

## 0.1.26 - Alkosh warning gating

- Shows the red Alkosh block warning only when Alkosh is active and a synergy prompt is visible.

## 0.1.25 - Alkosh panel spacing

- Gives the Alkosh warning its own row so it does not overlap uptime or target text.

## 0.1.24 - Alkosh timing precision

- Uses Line Breaker and the Trial Dummy aura as Alkosh's primary 10-second uptime sources.
- Keeps CombatMetrics penetration IDs as observed proc/calculation signals instead of primary timing sources.
- Caps displayed remaining duration and combat uptime sampling to the set's 10-second effect window.

## 0.1.23 - Roar of Alkosh MVP

- Adds a disabled-by-default Roar of Alkosh HUD tracker with Off, Warn, and visual Block warning modes.
- Detects the worn 5-piece set through a canonical set itemLink read with equipped-slot fallback, and tracks Alkosh/Line Breaker debuffs by abilityId.
- Reports last proc, remaining duration, combat uptime, and target information when ESO exposes it.
- Documents the safety limit that Alkosh Block warning mode does not intercept synergy input.

## 0.1.22 - Shared diagnostics control

- Registers the existing debug mode with EZOCore for family-wide disable control.
- Keeps the standalone settings control and SavedVariables ownership in EZOMetter.
- Restricts every movable meter, tracker and alert panel to left-button dragging.

## 0.1.21 - Shared layout integration

- Registers the aggregate EZOMetter HUD with EZOCore `family.layout` for global or individual movement control.
- Moves HUD unlock state from SavedVariables to explicit session runtime state.
- Keeps the standalone global HUD unlock control when EZOCore is unavailable.

## 0.1.20 - EZOCore settings integration

- Registered the complete settings panel in Settings > EZO when EZOCore is available.
- Kept the standard LibAddonMenu panel only as a standalone fallback.

## 0.1.19 - Settings panel help

- Reworked the LibAddonMenu presentation with shared purple information headers and section-level tooltips.
- Moved permanent explanatory settings text into hover help while keeping field-specific tooltips.
- Updated English and Spanish documentation for the settings panel help layout.

## 0.1.18 - Public beta

- Prepared repository metadata, documentation, license, ignore rules, and line-ending rules for public beta publication.
- Added role-aware buff tracking groundwork and observed healing panel support.
- Added shared observed metric panel support for LibCombat-based damage/healing windows.
- Added Off Balance live/last-combat reporting improvements.
- Added Exploiter CP detection and estimated damage value during real Off Balance.
- Added Coral Riptide, DD stats, observed damage, and Fatecarver reporting improvements already present in the beta build.

## Notes

- This beta does not publish to Discord automatically.
- Derived combat metrics remain estimates when ESO does not expose direct attribution.
