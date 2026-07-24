# Punta della Dogana — art hand-off

The gameplay geometry is deliberately independent from the artwork. An illustrator
can replace section art, architecture, props and enemy images without editing
collision polygons or GDScript.

## Main art switchboard

Open `res://Levels/Scenes/Dogana/dogana_art_profile.tres` in Godot and replace the
texture assigned to a slot. The environment director and procedural scene builders
consume this resource at runtime.

- **Environment sections:** `arrival`, `customs`, `canal`, `fortuna`, `archive`
- **Architecture kit:** walkable platform, central wedge, tide altar
- **Breakables:** fishing cache, cracked urn, net bundle, fishbone wall
- **Characters:** tide bloater, lagoon oracle, drowned warden

Keep transparent padding tight around props. Section backgrounds should preserve
the existing aspect ratio and horizon line. Platform art must keep its walkable
top edge at the top of the source image; collision is defined separately.

## Animation-safe replacement

- Player frames: replace `res://Player/Sprites/player-Sheet.png` with the same grid
  dimensions (`5 × 8`). Animation timing and frame tracks remain in `Player.tscn`.
- Standard enemy frames: replace the texture configured on the enemy scene or art
  profile without changing its collision children. Procedural breathing, recoil
  and wind-up animation is applied to the sprite node.
- Props animate through their parent script (hit recoil, break squash and debris),
  so replacement images require no animation code.

## Layer contract

- Background section art: z `-18`
- Secret-room art: z `-2`
- Walkable platform body: z `-1`
- Player: z `2`
- Enemies and world props: z `0` or their scene-specific combat layer
- Fishing line and hook: z `14–20`

Do not add a procedural Line2D over the walkable edge. If an illustrator wants
foreground foot occlusion, it must be painted into a dedicated transparent prop
and reviewed per platform rather than stretched across the whole floor.
