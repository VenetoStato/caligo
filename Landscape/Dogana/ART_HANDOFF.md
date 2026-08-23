# Punta della Dogana — art hand-off

La geometria di gioco è indipendente dall’artwork. La disegnatrice può sostituire
fondali, architettura, props e personaggi **senza** toccare collisioni o GDScript.

## Flusso consigliato (più comodo)

1. Apri `Landscape/Dogana/ArtistDrop/LEGGIMI.md`
2. Metti i PNG con i nomi degli slot in `ArtistDrop/`
3. Esegui `python tools/sync_artist_drop.py` (o `.\tools\sync_artist_drop.ps1`)
4. Gioca la scena: le texture finiscono in `Illustrated/` / `Generated/` e sono
   già collegate da `dogana_art_profile.tres`

Comandi utili:

```bat
python tools/sync_artist_drop.py --status
python tools/sync_artist_drop.py --seed
python tools/sync_artist_drop.py 12_tide_altar.png
```

## Switchboard Godot

In alternativa puoi aprire `res://Levels/Scenes/Dogana/dogana_art_profile.tres`
e sostituire le texture slot per slot. Environment director e builder procedurali
la leggono a runtime.

- **Architecture principale:** sei slot `torre_fortuna`, `dogana_ovest`,
  `dogana_est`, `seminario`, `collegamento_salute`, `salute`
- **Interno Basilica della Salute:** `salute_interior_v2.png`, fondale laterale
  della navata; collisioni, ingresso e boss restano separati in Godot
- **Environment secondario:** arrival, customs, canal, fortuna
- **Architecture:** walkable platform, central wedge, tide altar
- **Breakables:** fishing cache, cracked urn, net bundle, fishbone wall
- **Lore props:** `Generated/Lore/customs_ledger.png`; il piede viene allineato
  automaticamente dalla scena `lore_lectern.tscn`, mentre titolo e testo restano
  esportati sul nodo. Puoi sostituire il PNG senza toccare Area2D o lettore UI.
- **Characters:** tide bloater, lagoon oracle, drowned warden

Props con trasparenza stretta. Fondali: tieni aspect ratio e orizzonte.
Platform: bordo calpestabile in **alto** nell’immagine.

## Animation-safe replacement

- Player: `res://Player/Sprites/player-Sheet.png` griglia `5 × 8`
- Nemici: texture da art profile / scena; breath/recoil/wind-up restano procedurali
- Props: hit/break restano nello script padre

## Layer contract

- Background section art: z `-18`
- Secret-room art: z `-2`
- Walkable platform body: z `-1`
- Player: z `2`
- Enemies / props: z `0` (o layer combat specifico)
- Fishing line / hook: z `14–20`

Niente Line2D procedurale sul bordo calpestabile: se serve occlusione piedi,
va dipinta in un prop trasparente dedicato.

## Regola fondamentale: piede a zero

Ogni prop gameplay (casse, urne, reti, nemici) ha il proprio `Node2D` al punto
di contatto con il terreno. L'artwork deve avere il piede sul bordo inferiore del
canvas, centrato in X, senza trasparenza inutile sotto. In questo modo il livello
aggancia automaticamente il prop alla collisione, anche su rampe.

- `breakable_fishing_cache.png`: 384 x 288, piede in basso.
- `breakable_urn.png` / `breakable_net_bundle.png`: soggetto appoggiato al bordo
  basso, nessuna ombra separata.
- Varianti enemy: soggetto centrato in X, piedi sul bordo basso; non includere
  ombre dipinte o elementi flottanti.

Le collisioni e i punti di ancoraggio restano nelle scene Godot: la disegnatrice
non deve mai editarli per sostituire un PNG.

## Punta della Dogana: brief visivo

La composizione di gameplay è una **vista laterale ortografica 2D**, non la pianta
triangolare vista dall'alto: da sinistra a destra devono leggersi Torre della
Fortuna, Dogana bassa e lunga, Seminario, quindi Santa Maria della Salute.
Banchina in pietra d'Istria chiara, arcate regolari, globo dorato di Fortuna e
cupola della Salute devono restare landmark immediati.
I sei moduli hanno baseline comune e scala uniforme per nodo. Cielo, acqua,
collisioni e piattaforme non fanno parte dei PNG architettonici.
Le superfici possono essere scure e umide per Caligo, ma la silhouette reale deve
restare riconoscibile.

## Asset replacement senza rompere il livello

1. Sostituisci una texture nel `DoganaArtProfile`; non spostare la scena gameplay.
2. Avvia `sync_artist_drop.py --status` e verifica nome/dimensioni dello slot.
3. In Godot, collisioni: `Gameplay/Geometry`; arte: `Environment` e
   `GeneratedPlatformArt`.
4. Per la composizione architettonica usa `Environment/Landmarks` e
   `Environment/Architecture`; non disegnare collisioni nell'immagine.

## Nemici: still + sheet (contratto Hollow Knight)

Gameplay e arte sono due file diversi. Il codice chiede solo nomi clip
(`idle`, `walk`, `wake`, `windup`, `attack`, `hurt`, `death`, `jump`).
L'illustratrice può:

1. Sostituire il ritratto still (`30_tide_bloater.png`, ecc.).
2. Aggiungere `30_tide_bloater_sheet.png` (8 celle in riga) per le animazioni.
3. Oppure assegnare un `SpriteFrames` nel `EnemyArtKit` (`Enemies/Art/*.tres`).

Regole Team Cherry che Caligo replica:

- Pivot ai piedi: il `CharacterBody2D` sta a terra, lo sprite è figlio.
- Hitbox e hurtbox sono Area2D, non pixel dello sheet.
- Telegraph (`wake`, `windup`) ha una posa unica, diversa dall'idle.
- I frame si possono riusare tra clip: una cella, tante animazioni.
- Il codice non legge i pixel. Cambia solo il kit / lo sheet.
