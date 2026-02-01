# Come importare un PSD e usarlo in scena (blocco con Sprite2D separati)

## Prima volta: installa Python e le librerie

1. **Installa Python** da [python.org/downloads](https://www.python.org/downloads/)  
   - Durante l’installazione **spunta "Add Python to PATH"**.

2. **Apri un terminale** (PowerShell o CMD) e scrivi:
   ```bash
   pip install psd-tools Pillow
   ```
   Premi Invio e attendi che finisca.

---

## Passo 1: Portare il PSD nel progetto

- **Opzione A** – Trascina il file `.psd` o `.psb` dalla cartella del PC nella cartella del progetto in Godot (pannello **FileSystem**, es. `Landscape/Sprites`).

- **Opzione B** – In Godot: menu **Project → Tools → PSD: Importa da file...**  
  Scegli il file PSD e la cartella di destinazione nel progetto (es. `res://Landscape/Sprites`), poi conferma.

---

## Passo 2: Far generare la scena dal PSD

1. Nel pannello **FileSystem** troverai il file (es. `MioLivello.psd`).
2. Godot lo importa in automatico e crea:
   - una cartella **`MioLivello_layers`** (con i PNG dei layer e `layers.json`);
   - un file **`MioLivello.tscn`** (la scena con un Node2D e uno Sprite2D per ogni layer).

Se compare l’errore **"export layer fallito"**:
- Controlla che Python sia installato e che tu abbia eseguito: `pip install psd-tools Pillow`.
- Riapri il terminale e riprova il comando, poi in Godot: **clic destro sul .psd → Reimport**.

---

## Passo 3: Mettere il “blocco” nella scena

1. **Apri la scena** dove vuoi il livello (es. `Levels/Scenes/test_area.tscn`).
2. Nel pannello **FileSystem** trova il **.tscn** generato dal PSD (es. `MioLivello.tscn`).
3. **Trascina** quel `.tscn` nella **viewport 2D** (la finestra con la scena) oppure nell’**albero della scena** (a sinistra).
4. Godot aggiunge un **Node2D** (es. "MioLivello") con tanti **Sprite2D** figli: uno per layer, già posizionati. È il tuo **blocco unico composto da Sprite2D separati**.

Puoi:
- Spostare il Node2D radice per spostare tutto il blocco.
- Nascondere o modificare singoli layer (i nodi Sprite2D figli).
- Cambiare l’ordine di disegno (ordine dei nodi nell’albero).

---

## Riepilogo

| Cosa fare | Come |
|-----------|------|
| **Prima volta** | Installa Python, poi `pip install psd-tools Pillow`. |
| **Importare un PSD** | Trascina il .psd nel FileSystem (o usa Project → Tools → PSD: Importa da file...). |
| **Usarlo in scena** | Trascina il **.tscn** generato (es. `MioLivello.tscn`) nella viewport 2D della tua scena. |

Il plugin PSD è in **addons/psd_import_plugin**. I pulsanti **PSD: Importa da file...** e **PSD: Esporta layer...** sono nella barra in alto dell’editor (accanto a Play).
