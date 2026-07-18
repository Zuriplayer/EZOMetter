# Changelog

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
