# Interactables (oggetti che reagiscono all'attacco)

Oggetti che reagiscono quando il player li colpisce con l’attacco (Attack_fast / Attack_strong).

## Script: attackable.gd

- **Hurtbox**: il nodo deve avere un figlio `Area2D` chiamato **Hurtbox** (rileva l’area di attacco del player, layer 4).
- **Comportamento** (export `behavior`):
  - **ANIMATE_ONLY** (0): alla botta riproduce l’animazione `hit_animation_name` (es. shake sui casoni).
  - **BREAK_ON_HIT** (1): riproduce `break_animation_name` e poi rimuove il nodo (es. tombe).

## Scene

- **Attackable.tscn** – Base generica (Sprite2D vuoto, animazioni "hit" e "break").
- **CasoniAttackable.tscn** – Casoni che fanno uno shake quando li colpisci. Sostituisci gli Sprite2D "Casoni" in scena con questa scena se vuoi che si animino.
- **Croce.tscn** – Croce (tomba) che si rompe al primo colpo (`behavior = BREAK_ON_HIT`), texture `croce.png`.
- **Tomba.tscn** – Come Croce (stessa logica, croce che si rompe).

## Uso

1. Inserisci **CasoniAttackable** o **Tomba** nella scena (es. sotto Ambiance come gli altri casoni).
2. Posiziona e scala come gli sprite attuali.
3. Per i casoni esistenti: puoi sostituire i nodi Sprite2D "Casoni" con un’istanza di **CasoniAttackable.tscn** (stessa posizione/scale).
