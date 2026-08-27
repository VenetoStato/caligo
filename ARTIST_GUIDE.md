# Caligo — spazio di lavoro della disegnatrice

Gli sprite presenti ora sono **placeholder**: possono essere ridisegnati,
sostituiti o eliminati. Non esiste una palette imposta dal progetto. Palette,
stile, tecnica, silhouette, proporzioni e quantità di frame sono decisioni della
disegnatrice.

Godot reimporta automaticamente PNG, WebP e SVG salvati nel progetto. I file
`.import` sono cache generate e non vanno modificati a mano.

## Dove lavorare

- `Art/Editable/Player`: player e sue varianti.
- `Art/Editable/Characters/Enemies`: nemici e template per crearne di nuovi.
- `Art/Editable/Characters/Bosses`: boss.
- `Art/Editable/Environment`: ambienti e moduli.
- `Art/Editable/Props`: oggetti, piattaforme e lampadari.
- `Art/Editable/VFX`: texture facoltative per particelle e frammenti.

Cambiare soltanto il PNG esistente è il percorso più rapido, ma **non è un
vincolo**. Si possono creare nuovi file, cambiare canvas, aggiungere margini,
separare corpo/vestiti/armi su più immagini e rifare completamente le
animazioni. Se cambiano silhouette o punto d'appoggio, vanno riallineati sprite,
pivot e collisioni nella scena interessata.

## Player: più sprite e AnimationTree

Aprire `Player/Scene/Player.tscn`. Il nodo `VisualLayers` è lo spazio libero
della disegnatrice:

- duplicare `BodyOverlay` o aggiungere quanti `Sprite2D` si desiderano;
- usare `FreeAnimatedLayer` come base per `AnimatedSprite2D` indipendenti;
- assegnare texture, materiali, shader e ordine `z_index` liberamente;
- usare `ArtAnimationPlayer` per animare qualunque proprietà dei layer;
- creare stati e transizioni in `ArtAnimationTree`, poi attivarlo.

Se uno `Sprite2D` ha la stessa griglia del foglio base, il frame e il verso sono
sincronizzati automaticamente. Se usa una griglia diversa, lo controllano
`ArtAnimationPlayer`/`ArtAnimationTree`. Quando il tree artistico è spento, le
animazioni con lo stesso nome di quelle gameplay vengono riprodotte in
automatico. I nomi attuali sono `Idle`, `Walking`, `Jump`, `Falling`, `Fishing`,
`Attack_fast`, `Attack_strong`, `Attack_up`, `Attack_down`; si possono aggiungere
nomi e stati nuovi.

## Nemici: arte multilayer e animazioni libere

Ogni nemico accetta un `EnemyArtKit`. Il kit può contenere:

- uno still;
- uno `SpriteFrames` costruito liberamente nell'editor;
- uno sheet con righe, colonne e `clip_layout` configurabili;
- una lista senza limite di `EnemyArtLayer`, ciascuno con still o SpriteFrames,
  offset, scala, ordine e colore propri.

Le clip `idle`, `walk`, `wake`, `windup`, `attack`, `hurt`, `death`, `jump` sono
agganci usati dal gameplay, non una lista chiusa. Qualunque clip extra è valida
e può essere richiamata da una scena o da un comportamento con
`play_art_clip("nome")`.

Per aggiungere un nemico senza modificare quello condiviso, duplicare
`Enemies/ArtistEnemyTemplate.tscn` e seguire il README in
`Art/Editable/Characters/Enemies/_NEW_ENEMY_TEMPLATE`. Aspetto, statistiche,
dimensioni e kit diventano indipendenti. Un comportamento completamente nuovo
può usare uno script dedicato che estende `enemy.gd`.

## AnimationTree: procedura pratica

1. Selezionare `ArtAnimationPlayer` e creare le animazioni dei layer.
2. Selezionare `ArtAnimationTree`, aprire il pannello AnimationTree e aggiungere
   stati, blend e transizioni.
3. Collegare gli stati alle animazioni create e attivare `Active`.
4. Se servono parametri gameplay nuovi, assegnare nomi chiari e comunicarli al
   programmatore; gli sprite restano comunque modificabili dall'editor.

## Hitbox, pivot e verifiche

La grafica non determina automaticamente il danno. Dopo una silhouette nuova:

- player: controllare `CollisionShape2D` e le aree d'attacco in
  `Player/Scene/Player.tscn`;
- nemici: regolare `body_world_size`, Hurtbox e AttackHitbox nella scena clonata;
- boss: controllare `Levels/Scenes/Dogana/drowned_customs_warden.tscn`;
- arena/lampadari: controllare `Levels/Scenes/punta_della_dogana.tscn` e le scene
  in `Levels/Scenes/Dogana`.

Checklist minima: trasparenza corretta, pivot stabile durante l'animazione,
nessun frame tagliato e prova reale in movimento/attacco. Non c'è alcun
controllo di conformità a una palette.
