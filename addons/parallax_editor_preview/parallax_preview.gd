@tool
extends ParallaxBackground
## Attacca questo script a un ParallaxBackground per vedere il parallasse nell'editor.
##
## Come usare:
## 1. Aggiungi un ParallaxBackground con figli ParallaxLayer (e dentro ogni layer: Sprite2D, ecc.).
## 2. Attacca questo script al ParallaxBackground.
## 3. Nell'editor: cambia "Preview Offset" nell'Inspector (X e Y) e vedi i layer muoversi in tempo reale.
## 4. Oppure apri il pannello in basso "Parallax Preview" e muovi gli slider dopo aver selezionato il ParallaxBackground.
##
## In gioco lo scroll viene gestito dalla Camera2D come sempre; Preview Offset serve solo in editor.

@export var preview_offset: Vector2 = Vector2.ZERO

func _process(_delta: float) -> void:
	if Engine.is_editor_hint():
		scroll_offset = preview_offset
