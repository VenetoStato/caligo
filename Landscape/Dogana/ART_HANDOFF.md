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

- **Environment:** arrival, customs, canal, fortuna, archive
- **Architecture:** walkable platform, central wedge, tide altar
- **Breakables:** fishing cache, cracked urn, net bundle, fishbone wall
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
