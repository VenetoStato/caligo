# Controlli Android – pulsanti a schermo

## Cosa c’è ora

Su Android (e dispositivi touch) viene mostrato un **overlay di pulsanti** sopra il gioco:

- **Sinistra (basso):** ◀ sinistra, ▶ destra, ↑ salto  
- **Destra (basso):** Z attacco, **Forte** attacco forte, D dash  
- **Pesca (destra, riga sotto):** **Lenza** (cast), **Tira** (reel), **G** (grab/pastura), **Amo** (cambio amo)

I pulsanti sono **Control (Button)** con sfondo semi-trasparente, così si vedono e rispondono al tocco.  
Su Android i touch arrivano come mouse (Emulate Mouse From Touch), quindi i Button ricevono correttamente `button_down` / `button_up` e chiamano `Input.action_press()` / `Input.action_release()`.

## Impostazioni progetto

In **Project Settings → Input Devices → Pointing**:

- **Emulate Mouse From Touch:** **ON** (obbligatorio su Android perché i Button ricevano il tocco).
- **Android → Enable Long Press as Right Click:** **OFF** (evita che il long press “rubi” il tocco).
- **Android → Enable Pan and Scale Gestures:** **OFF** (evita che i gesti a due dita consumino l’input).

## Schermata comandi e hint

- La schermata **CONTROLLI** prima del gioco, su touch, mostra l’elenco dei comandi con **pulsanti a schermo** (◀ ▶ ↑, Z, Forte, D, Lenza, Tira, G, Amo).
- Gli **hint in-game** (combat e pesca) su touch indicano di usare quei pulsanti.

## Se i pulsanti non rispondono

1. Verifica che **Emulate Mouse From Touch** sia **ON**.
2. Riesporta l’APK dopo aver salvato `project.godot`.
3. Se ancora nulla, in editor prova con **Project → Run** e abilita **Emulate Touch From Mouse** per testare da desktop.
