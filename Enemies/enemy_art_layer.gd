class_name EnemyArtLayer
extends Resource

## Livello visivo opzionale completamente controllato dall'artista: corpo,
## abiti, arma, maschera, luce, ecc. Le clip con lo stesso nome del layer base
## vengono sincronizzate automaticamente.

@export var layer_name := "overlay"
@export var still: Texture2D
@export var frames: SpriteFrames
@export var offset := Vector2.ZERO
@export var scale_multiplier := Vector2.ONE
@export_range(-20, 20, 1) var z_offset := 1
@export var modulate := Color.WHITE
