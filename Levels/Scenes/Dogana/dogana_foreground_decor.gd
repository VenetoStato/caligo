extends Node2D

## I quay geometrici (rettangoli di pietra, archetti, cuneo) coprivano
## l'architettura dipinta. Il nodo resta per il gruppo di scena; il disegno no.


func _ready() -> void:
	z_index = -1
	visible = false
	set_process(false)
	set_physics_process(false)
