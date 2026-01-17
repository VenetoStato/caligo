# Come creare l'area dell'acqua - Guida passo passo

## Metodo 1: Creare nuova area acqua

### Passo 1: Apri la scena
1. Apri `test_area.tscn` nel Godot Editor
2. Vai nella gerarchia e trova dove vuoi l'acqua (es. sotto "Ambiance/0")

### Passo 2: Crea l'Area2D
1. Clicca destro sul nodo padre (es. "Ambiance/0")
2. Seleziona **Add Child Node**
3. Cerca e seleziona **Area2D**
4. Rinomina il nodo in **"Water"** (o "Water1", "Water2", ecc.)

### Passo 3: Aggiungi CollisionPolygon2D
1. Seleziona il nodo **Water** (Area2D) che hai appena creato
2. Clicca destro su **Water** → **Add Child Node**
3. Cerca e seleziona **CollisionPolygon2D**
4. Seleziona il **CollisionPolygon2D** appena creato

### Passo 4: Configura il poligono
1. Nel pannello **Inspector**, trova la proprietà **Polygon**
2. Clicca su **Polygon** → **Edit** (o clicca direttamente sul campo)
3. Nel viewport, disegna un rettangolo con 4 punti nell'ordine:
   - **Punto 0**: Top Left (alto sinistra) - clicca qui
   - **Punto 1**: Top Right (alto destra) - clicca qui
   - **Punto 2**: Bottom Right (basso destra) - clicca qui
   - **Punto 3**: Bottom Left (basso sinistra) - clicca qui
4. Premi **Enter** o clicca fuori per confermare

**IMPORTANTE**: I punti devono essere in questo ordine esatto!

### Passo 5: Attacca lo script
1. Seleziona il nodo **Water** (Area2D)
2. Nel pannello **Inspector**, nella sezione **Script**
3. Clicca su **"Attach Script"** (icona con freccia)
4. Seleziona `water_body.gd`
5. Clicca **"Create"**

### Passo 6: Configura l'Area2D
1. Seleziona il nodo **Water** (Area2D)
2. Nel pannello **Inspector**, assicurati che:
   - **Monitoring**: ✅ (spuntato)
   - **Monitorable**: ❌ (non spuntato)

## Metodo 2: Usare il viewport per posizionare

### Disegnare il poligono nel viewport:
1. Seleziona il **CollisionPolygon2D**
2. Nel viewport, vedrai i punti del poligono
3. Clicca e trascina i punti per posizionarli
4. Oppure usa le frecce per spostare l'intero poligono

### Esempio di configurazione:
```
Water (Area2D)
  ├─ CollisionPolygon2D
  │   └─ Polygon: 4 punti
  │       ├─ Punto 0: (-100, -50)  ← Top Left
  │       ├─ Punto 1: (100, -50)   ← Top Right
  │       ├─ Punto 2: (100, 200)   ← Bottom Right
  │       └─ Punto 3: (-100, 200)  ← Bottom Left
  └─ Script: water_body.gd
```

## Parametri da regolare (opzionale)

Nel nodo **Water** (Area2D), dopo aver attaccato lo script, puoi modificare:
- **k**: Tensione superficiale (default: 0.015)
- **d**: Smorzamento (default: 0.03)
- **spread**: Propagazione onde (default: 0.2)
- **distance_between_springs**: Distanza tra punti (default: 32)
- **spring_number**: Numero di spring (default: 6)
- **depth**: Profondità acqua (default: 1000)

## Verifica

Dopo aver creato l'area:
1. Avvia la scena (F5)
2. Dovresti vedere l'acqua blu trasparente
3. La superficie dovrebbe muoversi con onde
4. Quando il player entra, dovrebbe creare onde

## Problemi comuni

- **L'acqua non appare**: Verifica che il CollisionPolygon2D abbia esattamente 4 punti
- **Le onde non funzionano**: Controlla la console per errori
- **Il player non interagisce**: Assicurati che Monitoring sia attivo sull'Area2D
