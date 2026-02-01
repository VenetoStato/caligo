# Come importare file PSD in Godot

È stato installato l’addon **Godot-SimplePSD** nella cartella `addons/godot-simplepsd`.

## Requisito: Godot 4 Mono (con C#)

L’addon è scritto in **C#** e funziona solo con la versione **Mono** di Godot 4 (quella con supporto C#).

1. **Scarica Godot 4 Mono**  
   - Vai su [godotengine.org/download](https://godotengine.org/download)  
   - Scegli la versione **Standard** con **Mono** (.NET) per il tuo sistema (es. Windows 64-bit Mono).

2. **Apri il progetto con Godot 4 Mono**  
   - Avvia l’editor Mono (es. `Godot_v4.3_stable_mono_win64.exe`).  
   - Apri il progetto Caligo (il file `project.godot`).

3. **Abilita il plugin**  
   - Menu **Project → Project Settings → Plugins**.  
   - Trova **Simple PSD Importer** e attiva la casella (Enable).

4. **Compila il progetto C#**  
   - Menu **Build → Build Project** (oppure **Build → Build Solution**).  
   - Se il pulsante Build non compare, aggiungi un qualsiasi file `.cs` nel progetto e riprova.  
   - Attendi che la compilazione finisca senza errori.

5. **Importazione PSD**  
   - Copia i tuoi file `.psd` nella cartella del progetto (es. `Landscape/Sprites/` o `Player/Sprites/`).  
   - Godot li importerà come **Texture2D** (immagine unica, livello unico).  
   - In **Inspector → Import** puoi disattivare Mip Maps e regolare **Premultiply Alpha** se serve.

### Limitazioni (SimplePSD)

- Solo **8 bit per canale**.  
- In Photoshop, salva con **Maximize Compatibility** attivo (di solito è il default).  
- I **livelli** non vengono esportati separatamente (viene usata l’immagine composita).

---

## Alternativa senza Mono: esportare da Photoshop come PNG

Se non vuoi usare Godot Mono:

1. In **Photoshop**: **File → Export → Export As…** (o **Quick Export as PNG**).  
2. Scegli **PNG** e, se serve, **Trasparenza**.  
3. Salva nella cartella del progetto (es. `Landscape/Sprites/`).  
4. In Godot i PNG vengono importati come texture normalmente.

In questo modo non serve l’addon PSD né Godot Mono.
