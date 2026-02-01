# PSD → una texture per ogni livello

Lo script **`export_psd_layers.py`** apre un file PSD e salva **ogni livello** come **PNG separato**. Poi importi la cartella in Godot e usi le texture come vuoi.

## Uso

1. Installa dipendenze:
   ```bash
   pip install psd-tools Pillow
   ```
   Per effetti avanzati (forme vettoriali, gradienti): `pip install "psd-tools[composite]"`

2. Dalla root del progetto (o con percorso assoluto):
   ```bash
   python scripts/export_psd_layers.py "percorso/file.psd"
   ```
   Viene creata la cartella `file_layers/` con un PNG per ogni livello.

3. Con cartella di output personalizzata:
   ```bash
   python scripts/export_psd_layers.py "file.psd" "Landscape/Sprites/mio_psd_layers"
   ```

4. In Godot: trascina la cartella nel FileSystem; le PNG vengono importate come Texture2D.

## Esempio

```bash
python scripts/export_psd_layers.py "C:\Art\personaggio.psd" "res:\Player\Sprites\personaggio_layers"
```

Poi in Godot usi `Player/Sprites/personaggio_layers/livello1.png`, `livello2.png`, ecc.
