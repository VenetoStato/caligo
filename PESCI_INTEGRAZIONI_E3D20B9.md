# Implementazioni nel commit e3d20b96 – integrazione una alla volta

Commit: `e3d20b96ce86fe84393c23e0eaa7505bc37ac2d8`  
Messaggio: *"allora tutto quasi ben... la barca non si muove piu...."*

Qui sotto sono elencate le **modifiche rilevanti per i pesci** (e una per il player). Puoi riapplicarle una alla volta e testare i pesci dopo ogni passo per capire quale dà problemi.

---

## 1. **test_area.tscn – polygon acqua Water2 (espansione area)**

**Cosa fa:** Il `CollisionPolygon2D` di Water2 passa da area piccola a area molto grande.

- **Prima:**  
  `polygon = PackedVector2Array(-986.08, -234.82, 1084.66, -253.13, 1171.94, 85.59, -1049.42, 92.91)`  
  (area circa x -1049..1171, y -253..92)

- **Dopo:**  
  `polygon = PackedVector2Array(-986.08, -234.82, 2821.78, -260.46, 2799.26, 1151.21, -1007.19, 1195.15)`  
  (area circa x -1007..2821, y -260..1195)

**Perché può influire sui pesci:** In `water_body.gd` i pesci vengono spawnati in `min_x..max_x` e `min_y..max_y` del polygon. Con l’area enorme e solo 5 pesci, finiscono sparsi e lontani dalla camera.

---

## 2. **water_body.gd – scala varianti e zona di spawn Y**

**2a – Scala varianti 0.1 → 0.06**

- `fish.set_fish_texture(tex, 0.1)` → `fish.set_fish_texture(tex, 0.06)`
- `fish.scale = Vector2(0.1, 0.1)` → `var fish_scale := 0.1`; se variante `fish_scale = 0.06`; `fish.scale = Vector2(fish_scale, fish_scale)`
- Scala di `CollisionShape2D`: da `0.1` fissa a `fish_scale`
- Per i pesci non varianti: stesso `sprite.scale = Vector2(0.1, 0.1)` come prima

**2b – Spawn in tutta la colonna d’acqua (10%–90% altezza)**

- **Prima:**  
  `random_y = randf_range(min_y + (max_y - min_y) * 0.3, max_y - 20)`  
  (solo parte bassa, ultimi 70% dell’altezza)

- **Dopo:**  
  `random_y = randf_range(min_y + (max_y - min_y) * 0.1, min_y + (max_y - min_y) * 0.9)`  
  (dal 10% al 90% dell’altezza, tutta la colonna)

---

## 3. **fish.gd – profondità, varianti sprite, zona fondale**

**3a – max_depth_from_bottom e commento**

- `max_depth_from_bottom: float = 80.0` → `200.0`
- Commento: da “Profondità massima dal fondale” a “Quanto possono stare sopra il fondale…”

**3b – Varianti sprite (boops/sarago) – flip invertito**

- Nuova variabile: `var _variant_sprite: bool = false`
- In `set_fish_texture`: aggiungere `_variant_sprite = true`
- In `_update_sprite_direction`:  
  - calcolare `flip_right` / `flip_left`  
  - se `_variant_sprite`: scambiare (flip_right = abs, flip_left = -abs)  
  - usare quelli al posto di `-abs(sprite.scale.x)` / `abs(sprite.scale.x)`

**3c – _keep_near_bottom – zona comoda 30%–150%**

- Soglia “troppo in alto”: da `max_depth_from_bottom` a `max_depth_from_bottom * 1.5`, push 5.0 → 2.0
- Soglia “troppo in basso”: da `max_depth_from_bottom * 0.5` a `max_depth_from_bottom * 0.3`, push 3.0 → 2.0

---

## 4. **player_controller.gd – particelle e container**

**4a – _ready: fallback load particelle**

- Se `black_particle_scene == null` → `load("res://Fx/black_particle.tscn")`
- Se `ambient_trail_scene == null` → `load("res://Fx/ambient_particle.tscn")`

**4b – Container particelle = get_parent() invece di current_scene**

- In `_spawn_death_particles`: `var container = get_parent() ?? current_scene`; `container.add_child(p)` invece di `current_scene.add_child(p)`
- In `_spawn_particles` e `_spawn_trail`: stesso schema (container = get_parent(), fallback current_scene/root), poi `container.add_child(p)`

*(Non tocca direttamente i pesci, ma è nello stesso commit.)*

---

## Ordine suggerito per il test

1. **Solo player_controller (4)** – verificare che i pesci restino ok.
2. **Solo fish.gd (3)** – prima 3a, poi 3b, poi 3c; test dopo ognuno.
3. **Solo water_body (2)** – prima 2a, poi 2b; test dopo ognuno.
4. **Solo test_area – polygon Water2 (1)** – test pesci con area grande.

Dopo il ripristino dei 4 file allo stato **prima** di e3d20b96, riapplica questi blocchi uno alla volta e controlla ogni volta se i pesci compaiono e si comportano bene.
