# Caligo UI hand-off

## Visual changes

- Global fonts, colors and common controls live in `caligo_ui_theme.tres`.
- Display and body fonts live in `UI/Fonts`.
- Intro artwork is referenced by the relevant screen script; Dogana world artwork
  remains centralized in `dogana_art_profile.tres`.

## Responsive layout

`responsive_layout.gd` is the shared source for compact breakpoints, UI scale and
maximum panel fitting. Splash, controls, prologue, loading, tutorial, HUD and
Android controls listen to viewport resize events and recalculate their layout.

When changing a screen:

1. Use containers and anchors instead of absolute screen coordinates.
2. Keep a maximum desktop width, but calculate the actual width from the viewport.
3. Wrap long labels and put dense content in a `ScrollContainer`.
4. Test at `1280×720`, `960×540`, `720×1280` and `1920×1080`.
5. Keep gameplay art and UI art separate; UI must not alter world z-order.

The player is intentionally rendered in front of altars and props. Walkable
platform scripts must not create a `Line2D` overlay across the player’s feet.
