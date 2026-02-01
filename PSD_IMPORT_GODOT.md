# Come importare file PSD in Godot 4

Godot **non supporta nativamente** i file Photoshop (PSD). Puoi usare uno di questi metodi.

---

## 1. Esportare da Photoshop come PNG (consigliato)

- In Photoshop: **File → Export → Export As…** (o **Quick Export as PNG**).
- Scegli **PNG** e, se serve, **Trasparenza**.
- Salva nella cartella del progetto (es. `Landscape/Sprites/` o `Player/Sprites/`).
- In Godot: trascina il PNG nella cartella; Godot lo importa come texture.

**Vantaggi:** nessun addon, nessun problema di compatibilità.  
**Svantaggio:** per cambiare il PSD devi riesportare manualmente.

---

## 2. Addon per importare PSD direttamente

### Opzione A: Godot 4-Importality (grafica generica)

- **Repo:** [nklbdev/godot-4-importality](https://github.com/nklbdev/godot-4-importality)
- Supporta vari formati raster e animazioni; per i PSD verifica la documentazione del progetto.
- Installazione: clona/copia l’addon nella cartella `addons/` del progetto e attivalo in **Project → Project Settings → Plugins**.

### Opzione B: Godot PSD Importer (Rust, solo PSD)

- **Repo:** [bram-dingelstad/godot-psd-importer](https://github.com/bram-dingelstad/godot-psd-importer)
- Addon per Godot 4 che importa PSD (scritto in Rust).
- Segui le istruzioni nel README per compilare/installare l’addon in `addons/`.

### Opzione C: Godot KRA/PSD Importer (Godot 3.x, da verificare per 4.x)

- **Asset Library:** [Godot KRA/PSD importer](https://godotengine.org/asset-library/asset/567)
- Nato per Godot 3.1+; su Godot 4 potrebbe richiedere adattamenti. Controlla se esiste una versione compatibile con Godot 4.

---

## 3. Workflow consigliato per questo progetto

1. **Lavoro in Photoshop:** disegni e livelli nel PSD.
2. **Export:** esporti i layer/frame che ti servono come **PNG** (singoli o sprite sheet).
3. **Godot:** usi i PNG come texture (Sprite2D, AnimatedSprite2D, ecc.).

Se vuoi aggiornare spesso dal PSD senza riesportare a mano, puoi provare uno degli addon sopra (in particolare Importality o godot-psd-importer) e verificare che funzionino con la tua versione di Godot 4.
