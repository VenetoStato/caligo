# Drop art — Punta della Dogana

Cartella pensata per la disegnatrice: **non serve toccare script né collisioni**.

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
| `30_tide_bloater.png` | Nemico (ritratto) | 512×436 |
| `31_lagoon_oracle.png` | Nemico (ritratto) | 431×512 |
| `32_drowned_warden.png` | Boss (ritratto) | 512×512 |
| `30_tide_bloater_sheet.png` | Sheet 8 clip | 4096×436 |
| `31_lagoon_oracle_sheet.png` | Sheet 8 clip | 3448×512 |
| `32_drowned_warden_sheet.png` | Sheet 8 clip boss | 4096×512 |

### Animazioni nemico (stile Hollow Knight)

Il ritratto still è sufficiente. Per far muovere il personaggio a frame, lascia
nella stessa cartella lo sheet `*_sheet.png` accanto al PNG still: il gioco lo
carica da solo, senza toccare script o collisioni.

Clip obbligatorie, da sinistra a destra sulla riga:

`idle` `idle` `walk` `walk` `wake` `windup` `attack` `hurt/death`

- Una cella può essere riusata in più clip (Team Cherry fa così).
- Piedi sul bordo basso di **ogni** cella, stessa larghezza/altezza.
- `wake` e `windup` devono avere una posa unica e leggibile: sono il telegraph.
- Collisioni e hitbox restano in Godot. Non disegnarle nello sheet.

### Interno della Salute

`00g_salute_interior.png` è il fondale laterale della navata e dell'arena boss
(1774×887). Può essere sostituito senza toccare collisioni, porta o boss.

## Regole rapide

- **Moduli laterali:** camera ortogonale, PNG trasparenti, piede sul bordo inferiore; niente vista aerea o isometrica.
- **Fondali:** tieni l’orizzonte allineato agli altri.
- **Platform:** il bordo calpestabile deve stare **in alto** nell’immagine.
- **Props / nemici / altare:** PNG trasparente, poco padding vuoto.
- **Non** disegnare collisioni: restano nel livello.
- Player sheet separato: `Player/Sprites/player-Sheet.png` (griglia 5×8).

Dettagli tecnici: `Landscape/Dogana/ART_HANDOFF.md`.
