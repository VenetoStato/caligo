# Parallax Editor Preview

Vedi l’effetto parallasse **nell’editor** (senza avviare il gioco).

## Setup

1. **Abilita il plugin**: Project → Project Settings → Plugins → attiva **Parallax Editor Preview**.

2. **Crea il parallasse** (se non ce l’hai già):
   - Aggiungi un nodo **ParallaxBackground** (figlio della root o della Camera2D).
   - Aggiungi figli **ParallaxLayer**; in ogni layer metti uno **Sprite2D** (o altro).
   - Imposta **Motion Scale** su ogni ParallaxLayer (es. 0.5 = sfondo lento, 1.0 = fisso, 1.2 = più veloce).

3. **Attacca lo script di preview**:
   - Seleziona il **ParallaxBackground**.
   - Nell’Inspector: Attach Script → cerca `parallax_preview.gd` in `addons/parallax_editor_preview/` (oppure trascina lo script sul nodo).

## Come vedere il parallasse nell’editor

**Opzione A – Inspector**  
Con il ParallaxBackground selezionato, nell’Inspector trovi **Preview Offset (X, Y)**. Cambia X o Y e vedi i layer muoversi in tempo reale nella viewport 2D.

**Opzione B – Pannello in basso**  
Apri il pannello in basso **Parallax Preview** (tab accanto a Output/Debug). Seleziona il ParallaxBackground (o un suo figlio). Appaiono gli slider **X** e **Y**: muovili per vedere il parallasse nell’editor.

In gioco lo scroll è gestito dalla Camera2D come sempre; Preview Offset serve **solo in editor** per regolare le proporzioni dell’effetto.
