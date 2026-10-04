# Cashew (fork) — istruzioni per agenti

Fork personale di [jameskokoska/Cashew](https://github.com/jameskokoska/Cashew): app Flutter per gestire spese e budget (Android, iOS, web/PWA). Tutto il codice è in `budget/`. L'obiettivo del fork è sviluppare e deployare nuove feature in autonomia: l'autore upstream **non accetta PR**, quindi niente contributi verso upstream.

- `origin`: `git@github.com:omartrj/Cashew.git` (il fork, si pusha qui)
- `upstream`: `git@github.com:jameskokoska/Cashew.git` (solo fetch; ultimo cambio al codice a ottobre 2024)

## Regole d'oro

1. **Usa sempre `fvm flutter` / `fvm dart`**, mai `flutter` o `dart` direttamente. Il progetto è fissato a **Flutter 3.19.6** (`budget/.fvmrc`), la stessa versione usata upstream.
2. **Non aggiornare Flutter né le dipendenze** (`pubspec.yaml` / `pubspec.lock`) senza chiedere. Con Flutter 3.24 il progetto non compila: `intl`, `carousel_slider`, `device_preview` e `home_widget` sono incompatibili. Dettagli in `docs/agent/environment.md`.
3. **Ogni modifica alle tabelle Drift richiede una migrazione** (bump di `schemaVersionGlobal`, schema dump, steps): procedura completa in `docs/agent/codebase.md`. Non modificare mai a mano `tables.g.dart` e `schema_versions.dart`, che sono generati.
4. Per navigare usa `pushRoute(context, page)`, per la piattaforma `getPlatform()` (entrambi in `lib/functions.dart`). Mai `Navigator.push` né `dart:io` `Platform`, che non funziona sul web.
5. Le stringhe UI passano per le traduzioni (`"chiave".tr()`, easy_localization). **Non lanciare `generate-translations.py` così com'è**: scarica il Google Sheet dell'autore e sovrascrive le chiavi aggiunte nel fork. Vedi `docs/agent/codebase.md`.
6. **Non ci sono test** (`test/widget_test.dart` è il template vuoto di Flutter). Verifica sempre con `analyze` più una build, e chiedi all'utente di provare l'app.
7. Prima di committare o pushare, chiedi. Lavora su un branch per la feature, non su `main`.

## Comandi (da `budget/`)

```bash
fvm flutter pub get
fvm flutter analyze --no-pub          # baseline: 0 errori, ~236 info/warning già presenti upstream
fvm flutter run -d chrome             # sviluppo web (CHROME_EXECUTABLE=/usr/bin/chromium)
fvm flutter run                       # su telefono Android collegato (adb)
fvm flutter build web --release --web-renderer canvaskit --no-tree-shake-icons   # come firebase.json
fvm flutter build apk --debug         # la prima build Gradle richiede ~5 min
fvm dart run build_runner build       # codegen Drift (rigenera tables.g.dart)
```

## Documentazione per agenti

- @docs/agent/environment.md — macchina, toolchain, variabili, problemi noti, accesso SSH
- @docs/agent/codebase.md — architettura, pattern, database, impostazioni, navigazione, checklist per una nuova feature
