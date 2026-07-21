# Caligo

Un gioco di pesca 2D sviluppato con Godot Engine 4.

## Caratteristiche

- Sistema di pesca con lenza dinamica
- Pesca come fonte di nutrimento: ogni cattura recupera un punto vita
- Sistema di dash stile Hollow Knight
- Acqua ibrida spring + shader, reattiva a player, barche e corpi
- Sistema di lotta con i pesci
- Grappling hook
- Punta della Dogana con esplorazione, area segreta e Altari della Marea
- Mappa illustrata con viaggio rapido tra gli altari scoperti

## Requisiti

- Godot Engine 4.5, renderer GL Compatibility

## Controlli

- **A/D**: Movimento sinistra/destra
- **Spazio**: Salto (doppio salto disponibile)
- **Doppio tap A/D**: Dash
- **Click sinistro**: Lancia fishing hook (con lenza)
- **G**: Lancia pastura (senza lenza)
- **R**: Reel (tira la lenza)
- **E**: Interagisci / riposa agli Altari della Marea
- **M**: Apri la mappa della Dogana

Su Android il pulsante `✦` sostituisce `E`. I controlli touch sono
semitrasparenti e compaiono esclusivamente durante il gameplay; non vengono
creati su Windows né nelle schermate introduttive.

## Punta della Dogana

È lo scenario predefinito dopo l'introduzione. Include pontili, bricole, due
bacini dinamici, combattimenti, un archivio segreto e il percorso fino alla
Fortuna. I tre Altari della Marea curano il player, salvano il respawn e,
quando scoperti, diventano destinazioni selezionabili dalla mappa. Il pulsante
Mappa è disponibile anche su Android. Dal selettore in alto puoi tornare
all'area originale.

I due bacini della Dogana contengono nove pesci complessivi. La cattura usa la
lotta con la tensione della lenza della demo originale e restituisce un punto
vita, con burst particellare, anello d'acqua e luce dinamica temporanea.

Avvicinandosi a un Altare della Marea compare un prompt persistente:
`E / ✦ RISVEGLIA L'ALTARE`. Dopo l'attivazione lo stesso comando cura il
personaggio e rende l'altare il nuovo punto di respawn.

Nel menu, **Regolazione acqua (dev)** apre un pannello normalmente nascosto con
slider persistenti per tensione, smorzamento, propagazione, forza splash,
galleggiamento, luce/riflesso e rifrazione.

## Verifica ed export

```powershell
godot --headless --path . --script res://tests/smoke_test.gd
godot --headless --path . --scene res://tests/water_benchmark.tscn --fixed-fps 60
godot --headless --path . --export-debug Android build/Caligo-Dogana-debug.apk
```

L'acqua usa automaticamente 32 campioni e 4 passaggi su Android, 48 campioni
e 8 passaggi su PC. I parametri sono regolabili su ogni nodo `WaterBody`.

## Sviluppo

Progetto in sviluppo attivo.
