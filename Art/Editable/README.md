# Asset attivi e liberamente modificabili

Il gioco punta realmente a questa cartella, ma i file presenti sono placeholder.
La disegnatrice decide palette, stile, proporzioni, tecnica e quantità di sprite.
Può sostituire i file esistenti oppure aggiungere nuove texture e collegarle
dall'Inspector.

- `Characters/Bosses`: boss.
- `Characters/Enemies`: nemici comuni e template per nuovi nemici.
- `Environment`: ambienti e moduli.
- `Player`: player, varianti e attacchi.
- `Props`: piattaforme, altari, lampadari e distruttibili.
- `VFX`: texture opzionali per effetti e frammenti.

Per sprite multilayer, AnimationTree, nuove animazioni, nuovi nemici e modifiche
alle hitbox leggere `ARTIST_GUIDE.md` nella root. Cambiare canvas e silhouette è
consentito: richiede soltanto di riallineare pivot e collisioni nella scena.
