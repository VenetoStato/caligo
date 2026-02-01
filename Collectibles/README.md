# Props / Obiettivi (tesori, leoni di San Marco)

## Dove sono i leoni di San Marco?

- **Prop.tscn** (`res://Collectibles/Prop.tscn`) è la scena generica per tesori/obiettivi.
- **LeoneSanMarco.tscn** (`res://Collectibles/LeoneSanMarco.tscn`) è una scena già configurata con `prop_id = "leone_san_marco_1"`: duplicala 3 volte e imposta `leone_san_marco_2` e `leone_san_marco_3` sulle altre due, poi assegna lo sprite del leone allo Sprite2D di ciascuna.

## Prop.tscn

- **Sprite**: Assegna la texture allo **Sprite2D** dall'Inspector (tu scegli lo sprite).
- **prop_id**: Identificativo. Per l’achievement **"Trova i 3 leoni di San Marco"** usa:
  - `leone_san_marco_1`
  - `leone_san_marco_2`
  - `leone_san_marco_3`
  (un id diverso per ognuno dei 3 prop in scena).
- **collect_effect_scene**: (opzionale) Scena particelle alla raccolta; vuoto = effetto oro default.
- Il player va sopra il prop → viene segnato come preso, parte l’effetto e l’achievement si aggiorna.

## Come usare

1. Aggiungi **Prop.tscn** oppure **LeoneSanMarco.tscn** nella scena (es. test_area).
2. Assegna la texture allo Sprite2D del prop (per i leoni: texture del leone di San Marco).
3. Per i 3 leoni: imposta **prop_id** su `leone_san_marco_1`, `leone_san_marco_2`, `leone_san_marco_3` sui tre prop.
