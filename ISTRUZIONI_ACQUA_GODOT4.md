# Istruzioni per configurare l'acqua dinamica in Godot 4

## Sistema convertito da Godot 3 a Godot 4

Ho convertito il sistema del tutorial di pixelipy per Godot 4:
- ✅ `export` → `@export`
- ✅ `onready` → variabili normali
- ✅ `instance()` → `instantiate()` (non usato, creiamo dinamicamente)
- ✅ `PoolVector2Array` → `PackedVector2Array`
- ✅ `body.motion` → `body.velocity` (per CharacterBody2D)
- ✅ `set_extents()` → `size` (per RectangleShape2D)
- ✅ `set_polygon()` → `polygon` (proprietà diretta)

## File creati

1. **`water_body.gd`** - Script principale dell'acqua
2. **`water_spring.gd`** - Script per ogni punto della superficie

## Come configurare nella scena

### Opzione 1: Se hai già i nodi Water e Water1

1. Apri `test_area.tscn` nel Godot Editor
2. Seleziona il nodo **Water** (Area2D)
3. Nel pannello Inspector, nella sezione **Script**:
   - Se c'è già uno script, clicca sulla freccia accanto e seleziona **"Detach Script"**
   - Poi clicca su **"Attach Script"**
   - Seleziona `water_body.gd`
4. Ripeti per il nodo **Water1**

### Opzione 2: Se i nodi Water non esistono più

1. Apri `test_area.tscn` nel Godot Editor
2. Vai nella gerarchia e trova dove vuoi l'acqua (es. sotto "Ambiance/0")
3. Clicca destro → **Add Child Node** → **Area2D**
4. Rinomina il nodo in **"Water"**
5. Aggiungi come figlio un **CollisionPolygon2D**
6. Nel CollisionPolygon2D, configura il poligono con 4 punti:
   - **Punto 0**: Top Left (alto sinistra)
   - **Punto 1**: Top Right (alto destra)
   - **Punto 2**: Bottom Right (basso destra)
   - **Punto 3**: Bottom Left (basso sinistra)
7. Seleziona il nodo **Water** (Area2D)
8. Nel pannello Inspector, clicca su **"Attach Script"**
9. Seleziona `water_body.gd`
10. Ripeti per creare **Water1** se necessario

## Configurazione del CollisionPolygon2D

Il poligono deve essere un rettangolo con 4 punti nell'ordine:
```
0 (top_left) -------- 1 (top_right)
|                           |
|                           |
3 (bottom_left) -------- 2 (bottom_right)
```

## Parametri regolabili

Nel `water_body.gd` puoi modificare nell'Inspector:
- **k**: Tensione superficiale (default: 0.015) - più alto = onde più rigide
- **d**: Smorzamento (default: 0.03) - più alto = onde si fermano prima
- **spread**: Propagazione onde (default: 0.2) - più alto = onde si diffondono di più
- **distance_between_springs**: Distanza tra i punti (default: 32) - più piccolo = superficie più dettagliata
- **passes**: Iterazioni per propagazione (default: 12) - più alto = onde più fluide
- **depth**: Profondità dell'acqua (default: 1000)
- **water_color**: Colore dell'acqua

## Come funziona

1. Il sistema crea automaticamente dei "spring" lungo la superficie superiore
2. Ogni spring usa Hooke's law (F = -K * x) per muoversi
3. Le onde si propagano tra spring adiacenti
4. Quando un corpo (player, oggetti) entra nell'acqua, spinge i spring vicini
5. La visualizzazione (Polygon2D) si aggiorna automaticamente

## Test

Dopo aver configurato:
1. Avvia la scena
2. Dovresti vedere l'acqua blu trasparente
3. La superficie dovrebbe muoversi con onde
4. Quando il player entra, dovrebbe creare onde

## Risoluzione problemi

- **L'acqua non appare**: Verifica che il CollisionPolygon2D abbia 4 punti nell'ordine corretto
- **Le onde non funzionano**: Controlla la console per errori
- **Il player non interagisce**: Assicurati che il player sia un CharacterBody2D o RigidBody2D
