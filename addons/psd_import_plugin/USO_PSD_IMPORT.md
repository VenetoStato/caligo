# Come usare l’import PSD/PSB (blocco unico con Sprite2D separati)

## Cosa fa l’importer

- Prende un file **.psd** o **.psb** e genera una **scena** (.tscn).
- La scena ha un **Node2D** radice e un **Sprite2D** per ogni layer, già posizionati come nel PSD.
- In scena vedi un **blocco unico** (tutti i layer impilati) ma ogni layer è un nodo separato che puoi spostare, nascondere o animare.

---

## 1. Dipendenza Python (solo al primo import)

L’importer usa **Python** con **psd-tools** e **Pillow** per leggere i layer.

**Installa una volta:**

1. Installa Python da [python.org](https://www.python.org/downloads/) (spunta “Add Python to PATH”).
2. Apri un terminale (PowerShell o CMD) e esegui:
   ```bash
   pip install psd-tools Pillow
   ```

Se non vuoi usare Python, puoi generare i layer a mano:

- Apri il terminale nella cartella del progetto (dove c’è `addons/psd_import_plugin/`).
- Esegui (sostituisci i percorsi con i tuoi):
  ```bash
  python addons/psd_import_plugin/export_psd_layers.py --for-godot "Landscape/Sprites/MioFile.psd" "Landscape/Sprites/MioFile_layers"
  ```
- In Godot: **clic destro sul .psd nel FileSystem → Reimport**. L’importer userà la cartella `*_layers` già creata e genererà la scena senza eseguire di nuovo Python.

---

## 2. Usare l’import per **qualsiasi** PSD/PSB

1. **Mettere il file nel progetto**
   - Trascina il .psd/.psb nella cartella che vuoi nel pannello **FileSystem**, oppure
   - **Project → Tools → PSD: Importa da file...** e scegli il file (viene copiato nel progetto).

2. **Import automatico**
   - Godot importa il PSD e crea accanto al file una **cartella** `NomeFile_layers` (con i PNG dei layer e `layers.json`) e un file **NomeFile.tscn** (la scena).

3. **Se compare “export layer fallito”**
   - Installa Python e `pip install psd-tools Pillow` (vedi sopra), oppure
   - Esegui a mano lo script `export_psd_layers.py --for-godot` come sopra e poi **Reimport** sul .psd.

---

## 3. Mettere il “blocco” in scena (Sprite2D separati)

1. Apri la scena 2D dove vuoi il livello (es. `test_area.tscn`).
2. Nel pannello **FileSystem** trova il **.tscn** generato dal PSD (es. `Lake_1.tscn`).
3. **Trascina** `Lake_1.tscn` nella **viewport 2D** (o nell’albero della scena).
4. Godot istanzia un **Node2D** (es. “Lake_1”) con tanti **Sprite2D** figli, uno per layer, già nella posizione giusta: è il tuo **blocco unico composto da Sprite2D separati**.

Puoi poi:
- Spostare il Node2D radice per spostare tutto il blocco.
- Nascondere/modificare singoli layer (i figli Sprite2D).
- Cambiare l’ordine di disegno (order dei nodi).
- Animare singoli layer.

---

## Errori TileSet (“Cannot create tile”, “no tile at (76, 22)”)

Questi messaggi **non** vengono dall’importer PSD. Di solito indicano che una **TileMap** nella scena usa un **TileSet** con riferimenti a tile inesistenti o fuori dall’atlante (es. tile a coordinate (76, 22) che non esiste).

- Controlla le TileMap nella scena e il TileSet assegnato.
- Se il TileSet era stato creato da un’immagine/PSD in passato, potrebbe essere stato cambiato o cancellato: riassegna il TileSet o correggi le tile usate dalla TileMap.

---

## Riepilogo

| Cosa vuoi fare | Come |
|----------------|------|
| Importare un nuovo PSD | Metti il .psd nel progetto (trascina o “PSD: Importa da file...”); Godot crea `NomeFile_layers` e `NomeFile.tscn`. |
| Usare il blocco in scena | Trascina il .tscn (es. `Lake_1.tscn`) nella viewport 2D; ottieni un Node2D con Sprite2D per ogni layer. |
| Evitare Python | Esegui a mano `export_psd_layers.py --for-godot`, poi Reimport sul .psd. |
