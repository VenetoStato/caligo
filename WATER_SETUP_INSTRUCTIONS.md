# Istruzioni per configurare l'acqua dinamica 2D

## Sistema implementato
Ho creato un sistema di acqua dinamica basato su 2DDynamicWater che usa:
- `water.gd` - Script principale che gestisce la superficie dell'acqua
- `waterpoint.gd` - Script per ogni punto della superficie (movimento Verlet)

## Come configurare l'acqua

### 1. Prepara le zone acqua esistenti

Nel file `test_area.tscn`, hai già due nodi "Water" e "Water1" che sono `Area2D`.

**IMPORTANTE:** Devi sostituire i `CollisionShape2D` con `CollisionPolygon2D`!

### 2. Per ogni zona acqua (Water, Water1):

1. **Rimuovi il CollisionShape2D esistente**
2. **Aggiungi un CollisionPolygon2D come figlio dell'Area2D**
3. **Configura il CollisionPolygon2D con 4 punti nell'ordine:**
   - Punto 0: Top Left (alto sinistra)
   - Punto 1: Top Right (alto destra)  
   - Punto 2: Bottom Right (basso destra)
   - Punto 3: Bottom Left (basso sinistra)

4. **Attacca lo script `water.gd` all'Area2D** (sostituisce `water_area.gd`)

### 3. Esempio di configurazione nel Godot Editor:

```
Water (Area2D)
  ├─ CollisionPolygon2D
  │   └─ Polygon: [top_left, top_right, bottom_right, bottom_left]
  └─ (water.gd script attaccato)
```

### 4. Parametri esportati in water.gd:

- `water_color`: Colore dell'acqua (default: blu trasparente)
- `surface_tension`: Tensione superficiale (default: 0.02)
- `damping`: Smorzamento delle onde (default: 0.98)
- `spread`: Propagazione delle onde (default: 0.026)
- `point_spacing`: Distanza tra i punti della superficie (default: 10.0)

## Come funziona

1. Il sistema crea automaticamente dei "waterpoints" lungo la superficie superiore
2. Ogni punto si muove con fisica Verlet (onde realistiche)
3. Quando un corpo entra nell'acqua, spinge i punti vicini
4. La visualizzazione e il collision polygon si aggiornano automaticamente

## Note

- I waterpoints vengono creati automaticamente quando la scena viene caricata
- La superficie reagisce quando corpi (player, oggetti) entrano nell'acqua
- Il sistema è ottimizzato per performance

## Prossimi passi

Dopo aver configurato le zone acqua, possiamo aggiungere:
- Fisica di galleggiamento per il player
- Spawn dei pesci nell'acqua
- Interazione con la pastura
