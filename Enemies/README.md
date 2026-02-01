# Nemici (Enemies)

## Enemy (enemy.tscn)

- **Comportamento:** resta in **Idle** finché non viene colpito dall’attacco del player (Z o click destro).
- **Dopo il colpo:** passa in **Aggro**, insegue il player, **saltella** a intervalli e può **colpire** il player se è vicino.
- **Layer:** Hurtbox su layer 2 (mask 4), così viene rilevata dall’area d’attacco del player (layer 4).
- **Uso:** aggiungi un’istanza di `res://Enemies/enemy.tscn` nella tua scena (es. test_area). Il player deve essere nel gruppo `"player"` e avere l’area d’attacco (AttackHitbox) attiva durante Attack_fast / Attack_strong.

## Sostituire lo sprite

Lo sprite di default è l’icona del progetto. Per usare il tuo nemico:
1. Assegna al nodo **Sprite2D** la texture che preferisci.
2. Se il tuo sprite ha frame (es. AnimatedSprite2D), puoi cambiare il nodo e aggiornare gli animation path nello script/AnimationPlayer.
