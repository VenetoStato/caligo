# Setup Particelle - Stile Hollow Knight

## ✅ Configurazione Completata

### File Creati:
1. **`Fx/black_particle.tscn`** - Particelle per effetti del player (dash, salto, attacco)
2. **`Fx/black_particle.gd`** - Script per particelle del player
3. **`Fx/ambient_particle.tscn`** - Particelle ambientali per atmosfera
4. **`Fx/ambient_particle.gd`** - Script per particelle ambientali

---

## 🎮 Particelle del Player

### Caratteristiche:
- ✅ Usano il **layer del player** (non layer 3)
- ✅ Appaiono durante: Dash, Salto, Attacco, Movimento (opzionale)
- ✅ Auto-rimozione dopo la durata

### Setup:
1. Apri `Player.tscn` nell'editor
2. Seleziona il nodo `CharacterBody2D` (Player)
3. Nell'Inspector, sezione **"Particle Effects"**:
   - Assegna `Fx/black_particle.tscn` a **`black_particle_scene`**
   - Attiva/disattiva gli effetti:
     - `particles_on_dash` ✅
     - `particles_on_jump` ✅
     - `particles_on_attack` ✅
     - `particles_on_move` (opzionale)

---

## 🌫️ Particelle Ambientali (Layer 3 - Parallasse)

### Caratteristiche:
- ✅ Usano il **layer 3** per effetto parallasse
- ✅ Particelle nere fluttuanti per atmosfera
- ✅ Variazione automatica del vento
- ✅ Configurabili nell'Inspector

### Setup:
1. Apri la scena del livello (es. `Levels/Scenes/test_area.tscn`)
2. Vai al nodo `Ambiance/3` (CanvasLayer layer 3)
3. Aggiungi come figlio: `Fx/ambient_particle.tscn`
4. Posiziona dove vuoi (le particelle si spargono in un raggio)
5. Configura nell'Inspector:
   - `particle_amount`: Numero di particelle (default: 50)
   - `lifetime`: Durata vita particelle (default: 8.0)
   - `emission_radius`: Raggio di emissione (default: 200.0)
   - `wind_strength`: Forza del vento (default: 5.0)
   - `auto_start`: Avvia automaticamente (default: true)

### Esempio di Posizionamento:
```
Ambiance/
  └── 3 (CanvasLayer layer=3)
      └── AmbientParticle (istanza di ambient_particle.tscn)
          └── CPUParticles2D
```

---

## 🔍 Verifica Configurazione

### Controlla che:
- [ ] `black_particle_scene` è assegnato nel Player
- [ ] Le particelle del player funzionano (dash, salto, attacco)
- [ ] Le particelle ambientali sono aggiunte al layer 3
- [ ] Le particelle ambientali sono visibili e si muovono

### Test:
1. **Player**: Esegui dash, salto, attacco → dovresti vedere particelle nere
2. **Ambientali**: Dovresti vedere particelle nere fluttuanti in background (layer 3)

---

## 📝 Note Tecniche

- **Particelle Player**: `z_index` dinamico, segue il player
- **Particelle Ambientali**: `z_index = 3`, effetto parallasse con `follow_viewport_scale = 1.3`
- Le particelle ambientali hanno vento variabile per effetto più naturale
- Tutte le particelle sono nere con fade-out per stile Hollow Knight
