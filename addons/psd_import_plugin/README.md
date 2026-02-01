# PSD / PSB Importer

Addon Godot (GDScript) per usare file **PSD** e **PSB**.

## Importare da fuori Godot (file non nel progetto)

Se il file .psd/.psb è **fuori** dal progetto (es. su Desktop o in un altro disco):

1. **Project → Tools → Importa PSD/PSB nel progetto (da file esterno)...**
2. Clicca **Sfoglia** e scegli il file .psd o .psb da qualsiasi cartella.
3. Scegli la cartella di destinazione nel progetto (default: `imported` → il file andrà in `res://imported/`).
4. Clicca **Copia nel progetto e importa**.

Il file viene copiato nel progetto, compare nel **FileSystem** e viene importato come scena. Poi trascina quel file dalla FileSystem nella **viewport 2D** per avere i layer separati in scena.

## Trascinare nella scena (un Sprite2D per layer)

Quando il file .psd/.psb è **già nel progetto** (nella FileSystem):

- Trascinalo dalla **FileSystem** nella **viewport 2D**: Godot lo importa come **scena** con un Node2D e **uno Sprite2D per ogni layer**, già posizionati come nel PSD.
- Se trascini dall’esterno e il file **non compare** nella FileSystem, usa prima **Importa PSD/PSB nel progetto (da file esterno)...** (vedi sopra).

**Requisito:** Python con `pip install psd-tools Pillow` (e `python` nel PATH).

## 2. Esporta i layer come PNG

**Menu:** Project → Tools → Import PSD layers...

Si apre una finestra con:
- Percorso file PSD/PSB (campo + Sfoglia)
- Cartella di destinazione PNG (campo + Sfoglia)
- **Controlla dipendenze**: verifica ImageMagick e Python+psd-tools
- **Importa layer**: esporta ogni layer come PNG separato e aggiorna il FileSystem

## Requisiti (uno dei due)

### 1) ImageMagick 7
- Installa [ImageMagick](https://imagemagick.org/script/download.php) e assicurati che `magick` sia nel PATH.
- Comando usato: `magick convert file.psd out.png` → genera `out-0.png`, `out-1.png`, …

### 2) Python + psd-tools
- Installa: `pip install psd-tools Pillow`
- L’addon esegue automaticamente lo script `export_psd_layers.py` in questa cartella.
- I PNG vengono nominati in base ai nomi dei layer (es. `mio_psd_Sfondo.png`).

## Uso

1. Abilita l’addon in **Project → Project Settings → Plugins**.
2. **Project → Tools → Import PSD layers...**
3. Scegli il file `.psd`.
4. Scegli la cartella di destinazione per i PNG (es. `res://Landscape/Sprites/`).
5. Godot aggiorna automaticamente il FileSystem dopo l’export.

## Script Python manuale

Se preferisci esportare da terminale:

```bash
python addons/psd_import_plugin/export_psd_layers.py file.psd [cartella_output]
```

Se ometti la cartella, i PNG vengono creati nella stessa cartella del PSD.
