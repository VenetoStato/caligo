# Sistema nemici aperto alla direzione artistica

`enemy.tscn` contiene il gameplay condiviso; l'aspetto viene assegnato con un
`EnemyArtKit`. Non impone palette, canvas, griglia o numero di layer.

Un kit può usare uno still, SpriteFrames creati nell'editor, uno sheet con layout
personalizzato e qualsiasi numero di `EnemyArtLayer` per corpo, abiti, armi,
maschere, luci o VFX. Le clip gameplay convenzionali sono `idle`, `walk`, `wake`,
`windup`, `attack`, `hurt`, `death`, `jump`; clip ulteriori sono ammesse e si
richiamano con `play_art_clip("nome")`.

Per creare un nuovo nemico:

1. duplicare `ArtistEnemyTemplate.tscn`;
2. creare e assegnare un nuovo `EnemyArtKit`;
3. scegliere liberamente asset, layer, animazioni, scala e statistiche;
4. regolare `body_world_size` e verificare collisione, Hurtbox e AttackHitbox;
5. aggiungere uno script derivato solo se serve un comportamento realmente nuovo.

I kit esistenti sono in `Enemies/Art`. Il template artistico e le istruzioni sono
in `Art/Editable/Characters/Enemies/_NEW_ENEMY_TEMPLATE`.
