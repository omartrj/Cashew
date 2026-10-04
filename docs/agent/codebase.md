# Panoramica della codebase

App Flutter **versione 5.4.3+416** (`budget/pubspec.yaml`), ~108k righe di Dart in `budget/lib`, esclusi i file generati. Il codice è di un solo autore, sviluppato dal 2021: niente architettura a livelli, stato globale diffuso, file molto lunghi. Segui lo stile esistente invece di introdurre pattern nuovi (Bloc, Riverpod, clean architecture…).

## Mappa della repo

```
Cashew/
├── budget/                      ← progetto Flutter (lavora qui)
│   ├── lib/
│   │   ├── main.dart            ← avvio e MaterialApp
│   │   ├── functions.dart       ← funzioni di uso generale (pushRoute, getPlatform, formattazione…)
│   │   ├── colors.dart          ← temi e colori dinamici (Material You)
│   │   ├── firebase_options.dart← config Firebase (progetto dell'autore!)
│   │   ├── database/            ← Drift/SQLite: tabelle, query, migrazioni
│   │   ├── struct/              ← stato globale e logica non-UI
│   │   ├── pages/               ← schermate (40) + homePage/ (14 sezioni della home)
│   │   ├── widgets/             ← widget riutilizzabili (87) + framework/, transactionEntry/, util/
│   │   └── modified/            ← reorderable_list modificata
│   ├── packages/                ← pacchetti abbandonati, copiati e modificati (sliding_sheet, implicitly_animated_reorderable_list)
│   ├── drift_schemas/           ← export JSON degli schemi DB (v33 → v47)
│   ├── assets/                  ← font, icone categorie, traduzioni, valute
│   ├── android/ ios/ web/       ← piattaforme (niente desktop)
│   └── test/                    ← vuoto (template)
├── promotional/                 ← immagini per store e README
├── scripts/                     ← .bat per Windows
└── docs/agent/                  ← questi documenti
```

File più grandi, da leggere a pezzi: `database/tables.dart` (7,7k righe), `pages/addTransactionPage.dart` (5,2k), `struct/iconObjects.dart` (4,5k), `pages/walletDetailsPage.dart` (3k), `widgets/showChangelog.dart` (2,7k), `pages/addBudgetPage.dart` (2,3k).

## Avvio (`lib/main.dart`)

`main()` → `Firebase.initializeApp` → `EasyLocalization` → `SharedPreferences` → `database = await constructDb('db')` → notifiche → JSON di valute e lingue → `initializeSettings()` → timezone → `runApp`.

Il `MaterialApp` ha come `home` un layout `NavigationSidebar` (desktop/web largo) + `InitialPageRouteNavigator`, e nel `builder` una catena di wrapper: `OnAppResume` → `InitializeBiometrics` → `InitializeNotificationService` → `InitializeAppLinks` → `WatchForDayChange` → `WatchSelectedWalletPk` → `WatchAllWallets`.

## Stato globale

Variabili top-level, inizializzate in `main()`:
- `database` (`FinanceDatabase`), `sharedPreferences`, `clientID`, `uuid`: in `struct/databaseGlobal.dart`.
- `appStateSettings` (`Map<String, dynamic>`): tutte le impostazioni utente, in `struct/settings.dart`.
- Molte `GlobalKey` per raggiungere lo stato di pagine e widget da ovunque (`appStateKey`, `pageNavigationFrameworkKey`, `homePageStateKey`, `snackbarKey`, `sidebarStateKey`…). È il meccanismo usato per forzare i refresh.

`provider` è tra le dipendenze ma è poco usato.

## Impostazioni

- I default sono in `struct/defaultPreferences.dart` (~250 chiavi). **Una nuova impostazione si aggiunge lì**; `initializeSettings()` aggiunge da sola le chiavi mancanti ai settings salvati.
- Lettura: `appStateSettings["chiave"]`.
- Scrittura: `await updateSettings("chiave", valore, updateGlobalState: true|false, pagesNeedingRefresh: [indici])`. Usa `updateGlobalState: true` solo se serve ricostruire tutta l'app (tema, lingua…), perché è costoso.
- Le impostazioni sono salvate come JSON in SharedPreferences (`userSettings`) e incluse nei backup.
- La UI delle impostazioni è in `pages/settingsPage.dart` (`MoreActionsPage`, `SettingsPageContent`); i widget riga sono in `widgets/settingsContainers.dart`.

## Database (Drift)

- Tutto in `database/tables.dart`: tabelle, enum, `@DriftDatabase` (`FinanceDatabase`) e circa 190 metodi di query. È il "repository" dell'app: aggiungi lì le nuove query.
- Tabelle: `Wallets` (in UI "Accounts"), `Transactions`, `Categories` (con sottocategorie), `CategoryBudgetLimits`, `AssociatedTitles`, `Budgets`, `AppSettings`, `ScannerTemplates`, `Objectives` (in UI "Goals"), `Tags` (tag globali del fork: le transazioni li referenziano con la lista JSON `Transactions.tagFks`), `DeleteLogs` (traccia le cancellazioni per la sync).
- **Le chiavi primarie sono stringhe UUID** (`text().clientDefault(() => uuid.v4())`), es. `transactionPk`, `categoryFk`, `walletFk`. Il wallet di default ha pk `"0"`.
- Convenzioni dei metodi: `watchX` / `getX` restituiscono `Stream` (la UI usa `StreamBuilder`), mentre le letture una tantum restituiscono `Future`. Le scritture passano da `createOrUpdateX(...)` (es. `createOrUpdateTransaction`, `createOrUpdateCategory`, `createOrUpdateBudget`), che gestiscono anche `dateTimeModified` e la sync: usa quelli, non insert/update diretti.
- Molti enum di dominio sono in cima a `tables.dart`: `TransactionSpecialType` (upcoming, subscription, repetitive, credit, debt), `BudgetReoccurence`, `ObjectiveType`, `ExpenseIncome`, `PaidStatus`, `HomePageWidgetDisplay`, `MethodAdded`…
- Implementazioni per piattaforma in `database/platform/`: nativa con `NativeDatabase` più executor in background; web con sql.js/WASM (`web/sql-wasm.*`).
- Generati, da non modificare a mano: `tables.g.dart`, `schema_versions.dart`.

### Migrazione dello schema (obbligatoria per ogni modifica a tabelle o colonne)

Versione attuale: `schemaVersionGlobal = 47` (`tables.dart`, riga ~29). Da `budget/`:

1. Modifica tabelle e colonne in `tables.dart`; preferisci colonne `nullable()` o con default, per non rompere i dati esistenti.
2. Porta `schemaVersionGlobal` a 48.
3. `fvm dart run build_runner build --delete-conflicting-outputs` (`budget/build.yaml` disattiva i "manager" di drift 2.18, così `tables.g.dart` resta simile a quello upstream)
4. `fvm dart run drift_dev schema dump lib/database/tables.dart drift_schemas/drift_schema_v48.json`
5. `fvm dart run drift_dev schema steps drift_schemas/ lib/database/schema_versions.dart`
6. In `MigrationStrategy.onUpgrade` (~riga 714) aggiungi il passo `from47To48: (m, schema) async { ... }` dentro `stepByStep(migrationSteps(...))` (~riga 869), seguendo il modello di `from46To47`.
7. Attenzione a import ed export: `widgets/importDB.dart`, `exportDB.dart`, `importCSV.dart` ed `exportCSV.dart` possono dover gestire la nuova colonna, così come la sync (`struct/syncClient.dart`).

## Navigazione e UI

- **Pagine principali** (indici in `widgets/navigationFramework.dart`, ~riga 357): 0 `HomePage`, 1 `TransactionsListPage`, 2 `BudgetsListPage`, 3 `MoreActionsPage`, 5 `SubscriptionsPage`, 6 `NotificationsPage`, 7 `WalletDetailsPage`, 8 `AccountsPage`, 9 `EditWalletsPage`… Si cambia pagina con `PageNavigationFramework.changePage(context, index)`.
- **Aprire una pagina**: `pushRoute(context, MyPage())` (`functions.dart`).
- **Struttura di una pagina**: si avvolge in `PageFramework` (`widgets/framework/pageFramework.dart`), che fornisce app bar collassabile, back, sliver e FAB. Guarda una pagina semplice esistente (es. `notificationsPage.dart`) come modello.
- **Popup e bottom sheet**: `openBottomSheet(context, PopupFramework(...))` (`widgets/openBottomSheet.dart`, `widgets/framework/popupFramework.dart`); `openPopup` in `widgets/openPopup.dart`; snackbar con `openSnackbar(SnackbarMessage(...))` (`widgets/openSnackbar.dart`).
- **Widget base dell'app**, da preferire a quelli Material grezzi: `Tappable` (al posto di InkWell/GestureDetector), `TextFont` (`widgets/textWidgets.dart`, al posto di Text), `Button`, `TextInput`, `SettingsContainer*`, `SelectItems`, `SelectChips`, `SelectAmount`, `CategoryIcon`.
- **Piattaforma**: `getPlatform()` restituisce `PlatformOS` e funziona anche sul web; `kIsWeb` per il web. Il layout si adatta a schermi larghi (sidebar e doppia colonna: `widgets/util/fullPageDoubleColumnLayout.dart`).
- **Tema**: Material You con colore d'accento personalizzabile (`colors.dart`); i colori si leggono con `getColor(context, "nome")` / `Theme.of(context).colorScheme`.

## Home page configurabile

- Le sezioni sono in `pages/homePage/` (budgets, objectives, netWorth, overdueUpcoming, creditDebts, spendingGraph, pieChart, heatMap, transactionsList…).
- Ordine e visibilità sono impostazioni: `homePageOrder` e `homePageOrderFullScreen` (con i marcatori `ORDER:LEFT` / `ORDER:RIGHT` per il layout a due colonne) in `defaultPreferences.dart`, più i flag `show*` letti con `isHomeScreenSectionEnabled(context, "showX")` (definita in `pages/editHomePage.dart`, usata nella mappa delle sezioni di `pages/homePage/homePage.dart`, ~riga 185).
- Per aggiungere una sezione: widget in `homePage/`, chiave nella mappa di `homePage.dart`, chiave negli ordini e nel flag `show*` in `defaultPreferences.dart`, voce nell'editor `pages/editHomePage.dart`.
- I widget della home **Android** (separati da questi) sono provider Kotlin in `android/.../budget/*WidgetProvider.kt`, aggiornati tramite `home_widget`.

## Traduzioni

- Libreria easy_localization. Nel codice: `"chiave-in-kebab-case".tr()`, anche con `namedArgs`.
- Sorgente: `assets/translations/translations.csv` (colonna `Key` + una colonna per lingua; `en` è la prima). Output: `assets/translations/generated/<lang>.json` (49 lingue), che è quello caricato dall'app.
- `generate-translations.py` **scarica prima il Google Sheet dell'autore e sovrascrive il CSV**, e usa separatori di percorso Windows (`"\\"`). Nel fork:
  - aggiungi le nuove chiavi al CSV (almeno `en` e `it`);
  - rigenera i JSON con una versione dello script senza download e con `os.path.join`, oppure, per poche chiavi, aggiungile direttamente in `generated/en.json` e `generated/it.json` tenendole allineate al CSV;
  - le chiavi senza traduzione ricadono su `en` (`useFallbackTranslations` in `struct/languageMap.dart`).

## Tag (feature del fork)

Tag globali (nome + colore) assegnabili a più transazioni, aggiunti dal fork nello schema v47.

- **Dati**: tabella `Tags` (`tagPk`, `name`, `colour`, `order`) e colonna `Transactions.tagFks`, lista JSON di `tagPk` (null se nessun tag), come `budgetFksExclude`. Niente tabella ponte: i tag viaggiano dentro la transazione, quindi la sync per riga funziona da sola; la tabella `Tags` è sincronizzata con `UpdateLogType.Tag` / `DeleteLogType.Tag`.
- **Query** (`tables.dart`): `createOrUpdateTag`, `watchAllTags`, `watchAllTagsIndexed`, `moveTag`, `deleteTag` (toglie il tag dalle transazioni prima di eliminarlo), `getTagInstanceGivenNameTrim`, `onlyShowBasedOnTagFks` (almeno uno dei tag).
- **Stato globale**: `Provider.of<AllTags>(context)` (`WatchAllTags` in `widgets/watchAllWallets.dart`, montato in `main.dart`); `tagsOf(tagFks)` restituisce i `Tag` di una transazione nell'ordine dell'utente.
- **UI**: gestione in `pages/editTagsPage.dart` (Impostazioni → Strumenti ed extra → Tag) e `pages/addTagPage.dart` (bottom sheet, restituisce il `Tag` salvato); selettore `widgets/selectTags.dart` nella pagina transazione e nel popup categoria; etichette in `transactionEntryTag.dart`; filtro `SearchFilters.tagPks` (chiave `tagPks` nella filter string).
- **CSV**: l'export ha la colonna `tags` (nomi separati da `; `), l'import la legge (anche `tag`/`labels`) e crea i tag mancanti.
- **Statistiche**: sezione "Tag" sotto le categorie della pagina All Spending / dettaglio account (`widgets/tagSpendingSummary.dart`, dentro `WalletCategoryPieChart`), con la query `watchTotalSpentInEachTag` (stessi filtri di periodo, uscite/entrate e conversione valuta del grafico categorie). Una transazione con più tag conta in ognuno; toccando un tag si apre la ricerca filtrata.
- **Non ancora fatto**: budget per tag, ricerca testuale sui nomi dei tag.

## Sync, backup e Firebase

- Sync tra dispositivi e backup passano da **Google Drive** (`struct/syncClient.dart`, `widgets/accountAndBackup.dart`): il DB intero viene caricato su Drive e unito con gli altri client tramite `dateTimeModified` e `DeleteLogs`.
- Firebase Auth e Firestore servono per i budget condivisi (`struct/shareBudget.dart`, `struct/firebaseAuthGlobal.dart`) e per il login.
- Il progetto Firebase è quello dell'autore: vedi `environment.md`.

## Altre funzioni utili da conoscere

- Valute e conversioni: `struct/currencyFunctions.dart` e `assets/static/generated/currencies.json`; tassi di cambio in `pages/exchangeRatesPage.dart`.
- Transazioni ricorrenti e in scadenza: `struct/upcomingTransactionsFunctions.dart`.
- Notifiche locali: `struct/initializeNotifications.dart`, `struct/notificationsGlobal.dart`.
- App link e automazione (creazione di transazioni via URL): `widgets/util/appLinks.dart`. Inserimento automatico da notifiche ed email: `pages/autoTransactionsPageEmail.dart`, `addEmailTemplate.dart`.
- Logging: `struct/logging.dart` (`captureLogs` avvolge `main`). Pagina debug: `pages/debugPage.dart`.
- Changelog mostrato all'utente: `widgets/showChangelog.dart`. Le nuove feature del fork possono essere annunciate qui.

## Nomi interni diversi dalla UI

| Codice | Interfaccia |
|---|---|
| `Wallet` / `walletPk` | Account |
| `Objective` | Goal |
| `TransactionSpecialType.credit` / `.debt` | Lent / Borrowed |
| `AssociatedTitle` | Titoli memorizzati che assegnano automaticamente la categoria |

## Checklist per una nuova feature

1. Crea un branch dal `main` del fork (`git switch -c feature/<nome>`).
2. Individua il pattern esistente più simile e copialo: pagina, sezione della home, impostazione, query.
3. Nuove impostazioni → `defaultPreferences.dart`. Nuove query → `tables.dart`. Nuove colonne o tabelle → migrazione completa (vedi sopra).
4. Ogni stringa visibile va nelle traduzioni (almeno `en` e `it`).
5. Verifica: `fvm flutter analyze --no-pub` (nessun nuovo errore rispetto alla baseline di 0), `fvm flutter run -d chrome` e/o una build APK, poi chiedi all'utente di provare il flusso a mano. Ricorda che la web e Android hanno backend DB diversi.
6. Valuta l'impatto su backup, sync, import ed export CSV se tocchi il modello dati.
7. Commit e push solo dopo conferma dell'utente.
