# Changelog

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
