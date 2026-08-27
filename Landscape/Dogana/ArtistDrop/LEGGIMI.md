# Drop art — Punta della Dogana

Cartella rapida per sostituire gli asset già collegati. Non impone palette,
tecnica, dimensioni o struttura delle animazioni. Per cambiare silhouette,
aggiungere layer, creare AnimationTree o nuovi nemici usare anche
`Art/Editable` e leggere `ARTIST_GUIDE.md`.

## Come sostituire un disegno

1. Esporta il PNG (con trasparenza per props/personaggi).
2. Rinominalo **esattamente** come nello slot (vedi tabella sotto o `SLOTS.json`).
3. Copialo in questa cartella `ArtistDrop/`.
4. Dalla root del progetto esegui:

```bat
python tools/sync_artist_drop.py
```

oppure in Godot: **Project → Tools → ArtistDrop: sincronizza disegni...**
(o il pulsante toolbar **ArtistDrop sync**).

5. Apri `BOARD.html` (generato dallo sync) per vedere tutti gli slot a colpo d'occhio.
6. Riavvia la scena in Godot (F5).

Comandi utili:

```bat
python tools/sync_artist_drop.py --status
python tools/sync_artist_drop.py --seed
python tools/make_artist_board.py --open
```

Lo script:
- copia il file nella destinazione corretta (`Illustrated/` o `Generated/`)
- toglie lo sfondo bianco/grigio di anteprima (se presente)
- avvisa se la risoluzione è diversa dallo slot consigliato

## Slot principali

Gli slot `00a_…` → `00f_…` compongono la facciata laterale modulare:
Torre → Dogana ovest → Dogana est → Seminario → collegamento → Salute.
Sono PNG trasparenti separati da cielo, acqua e collisioni. Ogni modulo può essere
sostituito da solo; conserva il piede sul bordo inferiore del canvas.

| File in ArtistDrop | Cosa è | Size consigliata |
|---|---|---|
| `01_arrival.png` … `04_fortuna.png` | Fondali sezioni | 1536×1024 |
| `10_quay_platform.png` | Pavimento calpestabile | 1024×371 |
| `11_central_wedge.png` | Cuneo Dogana | 1280×502 |
| `12_tide_altar.png` | Altare | 1024×1024 |
| `20_fishing_cache.png` | Cassa tutorial | 384×288 |
| `21_urn.png` / `22_net_bundle.png` | Props rompibili | 1024×1024 |
| `23_fishbone_wall.png` | Muro | 320×427 |
| `24_thorn_cluster.png` | Ciuffo spine (pogo) | 757×849 |
| `25_thorn_bed.png` | Striscia spine | 1482×486 |
| `30_tide_bloater.png` | Nemico (ritratto) | 512×436 |
| `31_lagoon_oracle.png` | Nemico (ritratto) | 431×512 |
| `32_drowned_warden.png` | Boss (ritratto) | 512×512 |
| `30_tide_bloater_sheet.png` | Sheet 8 clip | 4096×436 |
| `31_lagoon_oracle_sheet.png` | Sheet 8 clip | 3448×512 |
| `32_drowned_warden_sheet.png` | Sheet 8 clip boss | 4096×512 |

### Animazioni nemico — percorso rapido facoltativo

Il ritratto still è sufficiente. Per far muovere il personaggio a frame, lascia
nella stessa cartella lo sheet `*_sheet.png` accanto al PNG still: il gioco lo
carica da solo, senza toccare script o collisioni.

Lo sheet a 8 celle qui sotto è soltanto compatibilità con il vecchio drop rapido,
non un formato obbligatorio:

`idle` `idle` `walk` `walk` `wake` `windup` `attack` `hurt/death`

- Per griglie, quantità di frame e nomi diversi creare/modificare un
  `EnemyArtKit` nell'Inspector.
- Si possono aggiungere più `EnemyArtLayer` e clip extra senza limite.
- `wake` e `windup` sono agganci gameplay utili per il telegraph, non vincoli
  grafici.
- Se silhouette e punto d'appoggio cambiano, verificare le hitbox in Godot.

### Interno della Salute

`00g_salute_interior.png` è il fondale laterale della navata e dell'arena boss
(1774×887). Può essere sostituito senza toccare collisioni, porta o boss.

## Indicazioni tecniche, non vincoli artistici

- **Moduli laterali:** la sostituzione diretta è più semplice se i giunti restano
  compatibili; una composizione nuova può essere riallineata nella scena.
- **Fondali:** se cambia l'orizzonte, riallineare i nodi della scena.
- **Platform:** il bordo calpestabile deve stare **in alto** nell’immagine.
- **Props / nemici / altare / spine:** PNG **trasparente** (niente sfondo nero o bianco), poco padding vuoto, piede sul bordo basso.
- **Non** disegnare collisioni: restano nel livello.
- Player: usare `Art/Editable/Player` e `Player/Scene/Player.tscn`; il nodo
  `VisualLayers` accetta fogli, sprite e AnimationTree aggiuntivi con griglie libere.

Dettagli tecnici: `Landscape/Dogana/ART_HANDOFF.md`.
