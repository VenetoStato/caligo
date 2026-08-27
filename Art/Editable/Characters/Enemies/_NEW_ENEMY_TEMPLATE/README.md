# Nuovo nemico — cartella libera

Duplica questa cartella e rinominala con il nome del nuovo nemico. La palette,
la tecnica, la silhouette, la quantità di sprite e le dimensioni sono decisioni
della disegnatrice.

1. Duplica `res://Enemies/ArtistEnemyTemplate.tscn`.
2. Crea un nuovo `EnemyArtKit` dall'Inspector e assegnalo ad `art_kit`.
3. Usa liberamente `still`, uno `SpriteFrames`, uno sheet con `clip_layout`, o
   aggiungi più `EnemyArtLayer` per corpo, vestiti, armi, luci e VFX.
4. Regola `body_world_size` e le statistiche nel nuovo `.tscn`.
5. Prova hurtbox e hitbox nella scena: non dipendono dai bordi del PNG.

Le clip gameplay riconosciute automaticamente sono `idle`, `walk`, `wake`,
`windup`, `attack`, `hurt`, `death`, `jump`. Se ne possono creare altre senza
limiti e richiamarle con `play_art_clip("nome")`.
