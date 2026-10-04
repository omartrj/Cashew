# Ambiente di sviluppo

Stato verificato il 2026-10-04 con una verifica completa da zero (`flutter clean`, `pub get`, `analyze`, build web release, build APK debug): **tutto funzionante**.

## Macchina

- **PC personale dell'utente**: CachyOS (Arch Linux), utente `omar`, 12 core, 16 GB RAM.
- Repo in `~/Development/Cashew`; il progetto Flutter è in `~/Development/Cashew/budget`.
- **La shell di login è fish.** La sintassi bash (`$(...)`, `&&` in alcuni contesti, `export`) può fallire. Per script bash usa `bash -c '...'` o `bash -s <<'EOF' ... EOF`.
- **Niente sudo per l'agente**: i pacchetti di sistema li installa l'utente. Proponigli il comando esatto (`pacman` per i repo ufficiali, `yay` per l'AUR, mai con sudo davanti) e aspetta che lo lanci.

### Se l'agente lavora da remoto (WSL del PC di lavoro → SSH)

- Connessione: `ssh.exe pc-personale` (chiave già configurata, `-o BatchMode=yes` funziona).
- Le variabili universali di fish **non** arrivano agli script `bash -s` via SSH: esporta a mano `ANDROID_HOME`, `JAVA_HOME`, `CHROME_EXECUTABLE` e il PATH (valori sotto). In alternativa lancia i comandi con `fish -c '...'`.
- Per comandi lunghi (build Gradle) usa `nohup ... > /tmp/log &` sul PC e poi interroga il log: la connessione SSH è caduta più volte durante le build.
- `sshd` è attivo ma **non abilitato all'avvio**: dopo un riavvio del PC la connessione viene rifiutata. Va sistemato con `sudo systemctl enable sshd`, da far lanciare all'utente.

## Toolchain

| Componente | Versione / percorso | Note |
|---|---|---|
| fvm | 4.3.1 (`/usr/bin/fvm`, pacchetto `extra/fvm`) | cache SDK in `~/fvm/versions` |
| Flutter | **3.19.6** (Dart 3.3.4), fissato in `budget/.fvmrc` | stessa versione usata upstream |
| Java | OpenJDK 17 (`/usr/lib/jvm/java-17-openjdk`, default di `archlinux-java`) | richiesto da Gradle 7.5 |
| Android SDK | `/opt/android-sdk` (pacchetti AUR) | gruppo `android-sdk` con ACL rwx per `omar` |
| ↳ piattaforme | `android-34` (usata dal progetto), `android-37.0` | |
| ↳ build-tools | `30.0.3` (usati dal progetto), `37.0.0` | |
| ↳ licenze | accettate (`/opt/android-sdk/licenses`) | |
| Gradle | 7.5 (wrapper del progetto) | |
| Node / npm | Node 26 | |
| Firebase CLI | `firebase-tools` 15.x (`/usr/bin/firebase`) | non ancora loggato né configurato |
| Chrome | Chromium (`/usr/bin/chromium`) | per `flutter run -d chrome` |
| Editor | VS Code | Android Studio non installato (non serve) |

Variabili d'ambiente (fish universal, `set -Ux`):

```
ANDROID_HOME=/opt/android-sdk
JAVA_HOME=/usr/lib/jvm/java-17-openjdk
CHROME_EXECUTABLE=/usr/bin/chromium
fish_user_paths += /opt/android-sdk/platform-tools /opt/android-sdk/cmdline-tools/latest/bin
```

## Configurazione Android del progetto

`budget/android/app/build.gradle`: `compileSdkVersion 34`, `minSdkVersion 23`, `targetSdkVersion 34`, `applicationId "com.budget.tracker_app"` (quello dell'app originale sul Play Store). Kotlin 1.9.0. Le classi native (`MainActivity` e i provider dei widget della home Android) sono in `android/app/src/main/kotlin/com/example/budget/`.

Per pubblicare il fork come app distinta bisognerà cambiare `applicationId`. La firma release usa `key.properties` e `keystore.jks`, che non sono nella repo: vanno creati.

## Avvisi noti di `flutter doctor` (da ignorare)

- **"Android license status unknown"**: Flutter 3.19 non sa leggere l'output del nuovo `sdkmanager`, che ora è un wrapper della "Android CLI" e risponde "--licenses option is no longer needed". Le licenze sono accettate e la build APK funziona.
- **Linux toolchain / ninja mancante**: il progetto non ha la piattaforma desktop Linux (solo `android/`, `ios/`, `web/`).
- **Android Studio non installato**: non serve.

## Perché Flutter 3.19.6 e non una versione più recente

`budget/pubspec.lock` dichiara `flutter: ">=3.19.0"`, `dart: ">=3.3.0"` e fissa `intl` a 0.18.1, che è la versione imposta da Flutter 3.19. È stato provato Flutter 3.24.5:
- `pub get` fallisce perché Flutter 3.24 impone `intl` 0.19.0 (`^0.18.1` nel pubspec);
- anche con `intl: ^0.19.0`, la build fallisce dentro i pacchetti: `carousel_slider` 4.2.1 (conflitto con il `CarouselController` di Material), `device_preview` 1.1.0 (API `TextTheme`/`ThemeData` rimosse), `home_widget` 0.5.0 (parametro `size`).

Aggiornare Flutter significa aggiornare almeno quei pacchetti e ritestare carosello, anteprima dispositivi e widget della home. Va fatto solo se l'utente lo chiede, come attività separata.

## Firebase e deploy

- `main()` chiama `Firebase.initializeApp`, quindi Firebase è obbligatorio all'avvio.
- `lib/firebase_options.dart` e `firebase.json` puntano al progetto dell'autore (`budget-app-flutter`, sito di hosting `budget-track`). **Il fork non ha ancora un suo progetto Firebase.** Per deployare: l'utente crea il progetto e fa `firebase login`; poi `flutterfire configure` (va installato: `fvm dart pub global activate flutterfire_cli`) rigenera `firebase_options.dart`, e in `firebase.json` va aggiornato `site`.
- Login con Google, sync e backup su Google Drive dipendono dalla configurazione OAuth del progetto Firebase/Google Cloud.
- La workflow `.github/workflows/firebase-hosting-pull-request.yml` è dell'autore (usa `npm ci`, segreti non presenti nel fork): sul fork non funziona.
- Gli script in `scripts/*.bat` sono per Windows.

## Stato git al momento della stesura

`budget/.fvmrc` (nuovo) e la riga `.fvm/` aggiunta a `budget/.gitignore` da fvm: sono da committare insieme a questi documenti, quando l'utente lo conferma.
