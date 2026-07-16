# Changelog

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
