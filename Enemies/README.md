# Nemici (Enemies)

## Enemy (`enemy.tscn`)

- **Idle:** pattuglia corta. Se il player entra in `aggro_range` dopo `wake_delay`,
  passa in **Aggro** e riproduce la clip `wake`.
- **Aggro:** insegue, può saltare e colpire. Ogni attacco ha `windup` (telegraph)
  poi `attack`. I colpi ricevuti riproducono `hurt` e knockback.
- **Layer:** Hurtbox su layer 2 (mask 4). AttackHitbox accesa solo nei frame attivi.
- **Uso:** istanza `res://Enemies/enemy.tscn`. Il player deve essere nel gruppo
  `"player"`.

## Sostituire l'arte senza toccare il gameplay

Due livelli, come in Hollow Knight:

1. **Ritratto still** — PNG con i piedi sul bordo basso.
2. **Sheet opzionale** — stesso nome + `_sheet.png`, 8 celle in riga.

Il codice parla solo per nome clip. Collisioni e hitbox restano nel
`CharacterBody2D`.

Clip:

| Nome | Quando | Loop |
|---|---|---|
| `idle` | fermo / ronda | sì |
| `walk` | si muove | sì |
| `wake` | entra in aggro | no |
| `windup` | telegraph prima del colpo | no |
| `attack` | colpo / special | no |
| `hurt` | viene colpito | no |
| `death` | muore | no |
| `jump` | salto | no |

Assegnare un `EnemyArtKit` (`Enemies/Art/*.tres`) sul nemico o sul
`DoganaArtProfile`. Drop in `Landscape/Dogana/ArtistDrop/` e
`python tools/sync_artist_drop.py`.

Se c'è solo lo still, resta un respiro procedurale. Appena arriva lo sheet,
le clip a frame sostituiscono lo squash.
