# Interactables (oggetti che reagiscono all'attacco)

Oggetti che reagiscono quando il player li colpisce con l’attacco (Attack_fast / Attack_strong).

## Scena separata per i casoni colpibili

Conviene usare una scena dedicata: **CasoniColpibili.tscn**. Aprendola modifichi solo animazione e Hurtbox dei casoni colpibili.

## Come impostare l'animazione (casoni)

1. Apri **CasoniColpibili.tscn** (doppio clic nel FileSystem).
2. Seleziona **AnimationPlayer** → in basso apri il pannello **Animation**.
3. Animazione **"hit"**: modifica i keyframe di **Sprite2D:position** (shake) e **Sprite2D:scale** (pulse). Aggiungi tracce con **+** se serve (es. rotation).
4. Salva (Ctrl+S).

## Come modificare la collider (Hurtbox)

1. Apri **CasoniColpibili.tscn**.
2. Seleziona **Hurtbox** → figlio **CollisionShape2D**.
3. Inspector → **Shape**: se RectangleShape2D, cambia **Size** (larghezza, altezza) per allargare/restringere la zona colpibile. Puoi usare CircleShape2D (Radius).
4. **Hurtbox** → **Position**: sposta l'area per centrarla sullo sprite (es. come Sprite2D: `0, -30`).

## Script: attackable.gd

- **Hurtbox**: il nodo deve avere un figlio `Area2D` chiamato **Hurtbox** (rileva l’area di attacco del player, layer 4).
- **Comportamento** (export `behavior`):
  - **ANIMATE_ONLY** (0): alla botta riproduce l’animazione `hit_animation_name` (es. shake sui casoni).
  - **BREAK_ON_HIT** (1): riproduce `break_animation_name` e poi rimuove il nodo (es. tombe).

## Scene

- **CasoniColpibili.tscn** – Casoni colpibili (layer -1). Usa questa per modificare animazione e Hurtbox.
- **Attackable.tscn** – Base generica (Sprite2D vuoto, animazioni "hit" e "break").
- **CasoniAttackable.tscn** – Come CasoniColpibili (casoni colpibili).
- **Croce.tscn** – Croce (tomba) che al primo colpo si anima “rotta” e **resta lì** (non sparisce), texture `croce.png`.
- **Tomba.tscn** – Come Croce (stessa logica).

## Uso

1. Inserisci **CasoniAttackable** o **Tomba** nella scena (es. sotto Ambiance come gli altri casoni).
2. Posiziona e scala come gli sprite attuali.
3. Per i casoni esistenti: puoi sostituire i nodi Sprite2D "Casoni" con un’istanza di **CasoniAttackable.tscn** (stessa posizione/scale).
