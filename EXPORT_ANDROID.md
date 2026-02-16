# Export Android – Caligo

## Setup già fatto nel progetto

- **Export preset Android** in `export_presets.cfg`:
  - Percorso APK: `build/caligo.apk`
  - Package: `com.caligo.game`
  - Versione: 1.0 (version code 1)
  - Min SDK: 24, Target SDK: 34
  - Architetture: arm64-v8a + armeabi-v7a
  - Icona: `res://icon.svg` (per Play Store è meglio usare PNG 192x192 e 432x432)
- **Display** in `project.godot`: viewport 1280x720, stretch per mobile, orientamento landscape.

## Cosa devi fare tu (una volta per ambiente)

### 1. Installare OpenJDK 17

- Scarica da [Adoptium Temurin 17](https://adoptium.net/temurin/releases/?variant=openjdk17).
- Installa e annota il percorso (es. `C:\Program Files\Eclipse Adoptium\jdk-17.x.x`).

### 2. Installare Android SDK

- Installa **Android Studio** (2023.2.1 o successivo) da [developer.android.com/studio](https://developer.android.com/studio).
- Apri Android Studio → **More Actions** → **SDK Manager** e assicurati di avere:
  - **Android SDK Platform-Tools** 34.0.0+
  - **Android SDK Build-Tools** 34.0.0
  - **Android SDK Platform 34**
  - **NDK** r23c (23.2.8568313)
  - **CMake** 3.10.2.4988404  
  (oppure installa da **SDK Tools** tab)
- Il percorso SDK di solito è:  
  `C:\Users\<TUO_USER>\AppData\Local\Android\Sdk`

### 3. Configurare Godot

- In Godot: **Editor** → **Editor Settings** (o **Modifica** → **Impostazioni editor**).
- Sezione **Export** → **Android**:
  - **Java SDK Path**: cartella di installazione di OpenJDK 17.
  - **Android Sdk Path**: cartella Android SDK (es. `C:\Users\...\AppData\Local\Android\Sdk`).

### 4. Template di build Android (Gradle)

- In Godot: **Project** → **Install Android Build Template...**.
- Scegli la cartella del progetto (dove c’è `project.godot`).
- Verrà creata/aggiornata la cartella `android/` con i file Gradle.

### 5. Esportare l’APK

- **Project** → **Export...**.
- Seleziona il preset **Android**.
- Clicca **Export Project** e salva (es. `build/caligo.apk`; il percorso è già impostato nel preset).
- Per test su dispositivo: collega il telefono con USB debugging attivo e usa **Export & Run** oppure installa a mano l’APK.

## Icone per Play Store (consigliato)

Per un’app da pubblicare è meglio usare PNG:

- **Main icon**: 192×192 px (o maggiore).
- **Adaptive foreground**: 432×432 px (solo la parte “in primo piano”).
- **Adaptive background**: 432×432 px (sfondo, o colore pieno).

In **Project** → **Export** → preset **Android** → **Launcher Icons** imposta i percorsi a queste immagini.

## Problemi comuni

- **“Could not install to device”**: disinstalla la vecchia versione di Caligo dal telefono (stesso package name, chiave diversa).
- **“JDK not found”** / **“Android SDK not found”**: controlla i percorsi in Editor Settings → Export → Android.
- **Build Gradle fallisce**: rilancia **Project** → **Install Android Build Template...** e riprova l’export.
