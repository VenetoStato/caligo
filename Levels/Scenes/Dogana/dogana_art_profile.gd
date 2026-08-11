class_name DoganaArtProfile
extends Resource

## Single hand-off resource for illustrators. Replacing a texture here updates every
## Dogana scene that consumes the corresponding visual slot; gameplay collision,
## scripts and coordinates remain untouched.
##
## Flusso comodo: drop PNG in `Landscape/Dogana/ArtistDrop/` e
## `python tools/sync_artist_drop.py` (vedi LEGGIMI.md).

@export_category("Environment sections")
@export var arrival_background: Texture2D
@export var customs_background: Texture2D
@export var canal_background: Texture2D
@export var fortuna_background: Texture2D
@export var archive_background: Texture2D

@export_category("Architecture kit")
@export var walkable_platform: Texture2D
@export var central_wedge: Texture2D
@export var tide_altar: Texture2D
@export var tide_altar_scale := Vector2(0.145, 0.145)
@export var tide_altar_offset := Vector2(0.0, -58.0)

@export_category("Breakables")
@export var fishing_cache: Texture2D
@export var fishing_cache_scale := Vector2(0.25, 0.25)
@export var fishing_cache_offset := Vector2(0.0, -36.0)
@export var cracked_urn: Texture2D
@export var cracked_urn_scale := Vector2(0.14, 0.14)
@export var cracked_urn_offset := Vector2(0.0, -43.0)
@export var net_bundle: Texture2D
@export var net_bundle_scale := Vector2(0.15, 0.15)
@export var net_bundle_offset := Vector2(0.0, -42.0)
@export var fishbone_wall: Texture2D

@export_category("Characters")
@export var tide_bloater: Texture2D
@export var lagoon_oracle: Texture2D
@export var drowned_warden: Texture2D
