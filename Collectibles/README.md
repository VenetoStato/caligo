# Props / Obiettivi (tesori, leoni di San Marco)

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

1. Aggiungi **Prop.tscn** nella scena (es. test_area).
2. Assegna la texture allo Sprite2D del prop.
3. Per i 3 leoni: imposta **prop_id** su `leone_san_marco_1`, `leone_san_marco_2`, `leone_san_marco_3` sui tre prop.
