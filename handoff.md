# Money Manager — Handoff

Stand: 2026-07-03 · Code-Aufräumung + neue Tests committet (`1e851df`,
Nutzer hat zusätzlich Screenshots eingecheckt + zwei README-Altlasten
entfernt, `0ea243a`) · **uncommittet:** komplette Doku-Überarbeitung
(READMEs/ARCHITECTURE/supabase-README DE+EN aktualisiert, alle drei
Roadmap-Dateien gelöscht, pubspec-description) · **Finalisierungs-Phase
LÄUFT** — Fahrplan komplett; Archivierungs-E2E-Test vom Nutzer
**zurückgestellt** („noch keine zu archivierenden Jahre"); offen:
Doku-Commit/Push.

## Finalisierungs-Phase — Zwischenstand (Session 2026-07-03, Nachmittag)

- **`flutter analyze lib test` lief diesmal durch: „No issues found"**
  (185 s) — der Analyzer-Hänger aus Abschnitt 9 trat nicht auf. Keine
  einzige Warnung offen.
- **Splits-Notiz + Beträge-Toggle verifiziert, soweit ohne Login möglich:**
  - Preview-Browser: App bootet, Login-Screen rendert (inkl. des diskreten
    „Datenbank-Verbindung ändern"-Links). **Durchbruch fürs Tooling:** Klick
    auf `flt-semantics-placeholder` per `preview_eval` aktiviert Flutters
    Semantics → beschriftete, anklickbare DOM-Knoten (Abschnitt 9 ergänzt).
    Weiter als bis zum Login geht es aber nicht: die App hängt an der
    Produktiv-DB, Test-Login/Signup gegen Prod verbietet sich.
  - Als Ersatz **5 neue Tests** (jetzt 74 statt 69 — die früher notierten
    „70" waren leicht falsch gezählt): `test/hide_amounts_test.dart`
    (MoneyText zeigt `****`, Toggle schaltet um + persistiert in Prefs,
    3 Widget-Tests) und `test/split_note_test.dart` (Note-Roundtrip im
    Modell, 2 Tests). Speicher-/Prefill-Pfade der Splits-Notiz zusätzlich
    per Code-Lektüre bestätigt (Form → `replaceForTransaction` → DB-Spalte
    `note`). **Alle 74 Tests grün, `dart format` clean.** Der letzte Rest
    (eingeloggt im echten Browser klicken) bleibt beim Nutzer.
- **Toter-Code-Suche abgeschlossen** (Dateien, Provider, l10n-Getter/-
  Funktionen, Shared-Helfer): keine toten Dateien; Funde siehe
  Verbesserungsliste unten — bewusst **noch nichts gelöscht** (Schritt 4:
  erst mit Nutzer priorisieren).
- **Aufräumliste — vom Nutzer freigegeben und UMGESETZT (2026-07-03):**
  1. ✅ `myMembershipAccountIdsProvider` gelöscht
     ([account_member_providers.dart](lib/features/sharing/account_member_providers.dart)).
  2. ✅ `PeriodComparison.prevLabel` + deutscher `switch` (`'Vortag'` …)
     entfernt ([statistics_providers.dart](lib/features/statistics/statistics_providers.dart)) — damit ist der letzte
     unlokalisierte UI-String weg.
  3. ✅ `period_filter.dart`: `StatsPeriodX` (`label`, `contains`),
     `labelFor`, `_statMonths` entfernt; `shifted` + Provider bleiben.
     [period_filter_test.dart](test/period_filter_test.dart) auf die `shifted`-Gruppe reduziert
     (9 Testfälle mit raus → jetzt 65 Tests).
  4. ✅ l10n: `appTitle` via `onGenerateTitle` in [app.dart](lib/app.dart)
     verdrahtet; `archivedBadge` gelöscht (Archiv-Screens haben eigene
     Titel-/Read-only-Strings).
  Verifiziert: `flutter analyze` **No issues**, `flutter test` **65/65
  grün**, `dart format` **0 geändert**. Uncommittet (zusammen mit den zwei
  neuen Testdateien).
- **Archivierungs-E2E-Test: vom Nutzer ZURÜCKGESTELLT (2026-07-03,
  „noch keine zu archivierenden Jahre").** Falls später gewünscht, liegt der
  fertige Plan hier: temporärer Test-Admin (Whitelist-Eintrag
  `mm-e2e-archive@example.org`, Signup via REST, per SQL zum Admin),
  Test-Konto + eine Buchung in 2019 [Jahr verifiziert leer], archive-proxy
  write → `archive_commit_year` → read/list → De-Archiv → restloses Cleanup
  inkl. audit_log; GitHub-Archiv-Repo bekommt dabei 2 Commits. Achtung:
  schreibende Prod-Zugriffe brauchen eine interaktive Session mit
  Berechtigungs-Dialogen (Auto-Modus blockiert sie). Baseline 2026-07-03:
  2 Buchungen (beide 2026), 3 Konten, 0 archivierte Jahre, archive_config
  vollständig.
- **Doku komplett überarbeitet (2026-07-03, DE + EN):**
  - **Gelöscht:** `ROADMAP.md`, `ROADMAP.en.md`, `docs/ROADMAP_AUSBAU.md`
    (alle Phasen umgesetzt; Nutzer-Freigabe „kann entfernt werden").
  - **READMEs:** Intro/Stack um Web (PWA) + DE/EN ergänzt; „Status &
    Roadmap"-Abschnitt durch aktuellen „Funktionsumfang" ersetzt (Roadmap-
    Links entfernt); veraltetes Berechtigungsmodell („alle dürfen alles")
    durch das echte Modell ersetzt (Whitelist, Besitzer, RLS auf Besitzer+
    Freigaben seit 0018/0019); **falsche `env.json`-Vorrang-Aussage
    korrigiert** (Geräte-Override > connection.json > dart-define);
    Projektstruktur von Ledger-Ära auf heute gebracht; Setup verweist auf
    `setup.sql` statt `0001_init.sql`.
  - **docs/ARCHITECTURE(.en).md:** komplett neu geschrieben (waren noch auf
    Ledger-Stand): aktuelle Schichten, Verbindungs-Auflösung, Cache-then-
    Stream, Bottom-Nav-Routing, echtes Berechtigungsmodell, Web/PWA.
  - **supabase/README.en.md:** war Jahre hinter der DE-Version (Ledger,
    `npm i -g supabase`, 0001_init) → auf DE-Stand gebracht (setup.sql,
    Edge-Functions-Kapitel 2b inkl. `--no-verify-jwt`-Erklärung, aktuelles
    Datenmodell). DE-Version: hart codierter lokaler Pfad + project-ref
    des Produktiv-Projekts durch Platzhalter ersetzt.
  - `pubspec.yaml`-description um Web ergänzt.
- Ideen jenseits Aufräumen (unverändert offen, Abschnitt 10):
  iPhone/Safari-Login beobachten, Benachrichtigung bei Neuregistrierung.

## TL;DR — was diese Session (02.–03.07.2026) passiert ist

- Drei echte Bugs gefunden + gefixt: DB-Verbindung reagierte nicht zuverlässig,
  Fork-Repos verbanden sich unsichtbar mit der **Original-Produktiv-DB**
  (`connection.json`-Vorrang), `admin_wipe_data()` löschte versehentlich die
  Preset-Kategorien mit.
- Zugriffskontrolle gehärtet: E-Mail-Sichtbarkeit im Admin-Bereich, echter
  Zugriffsentzug bei Whitelist-Entfernung.
- Vier Alt-ToDos abgearbeitet (Archivierung verifiziert live, Passwort-ändern,
  Service-Worker-Fix, restliche Lokalisierung) + CI-Format-Fix.
- Neu: **Auto-Sync-Workflow für Forks**, **Freitext-Bezeichnung pro
  Teilsumme** (Splits), **Quick-Toggle „Beträge verbergen"** (`*` statt
  Punkte) auf Konten/Buchungen.
- `dart format` + `flutter test` (70/70) für **alles** grün.
  `flutter analyze` hing in dieser Umgebung wiederholt (Abschnitt 9) — nicht
  als alleinige Verifikation verwendet.
- **Nicht abschließend live im Browser getestet:** die beiden neuesten
  Features (Splits-Notiz, Beträge-Toggle) — Preview-Sandbox hing beim
  App-Start (Abschnitt 9). Kurzer manueller Gegentest empfohlen, sonst
  unauffällig.

Details/Begründungen zu jedem Punkt im ausführlichen Session-Log direkt
darunter — nur bei Bedarf lesen, für den Einstieg reicht das TL;DR + Abschnitt
10.

<details>
<summary>Ausführlicher Session-Log (02.–03.07.2026)</summary>

> **Zuletzt erledigt (diese Session):** **DB-Verbindungswechsel auf
> Android/Windows repariert** — `Supabase.initialize()` ist ab dem zweiten
> Aufruf ein No-Op, daher wirkte "Verbindung ändern" nach dem Speichern
> effektiv nicht (auf Web kaschierte "Seite neu laden" das zufällig). Fix:
> alte Supabase-Instanz wird disposed, neu initialisiert, kompletter
> Riverpod-Baum über neuen `ProviderScope`-Key verworfen/neu gebaut — kein
> manueller App-Neustart mehr nötig ([lib/main.dart](lib/main.dart) `_restart()`,
> Commit `9dde9e9`). Dazu **Easy-Setup per Web-Link**: Zugangsdaten lassen
> sich jetzt von einer bereits verbundenen Web-Version (GitHub Pages/git.io)
> per HTTP übernehmen statt URL/Key abzutippen
> ([lib/config/remote_connection.dart](lib/config/remote_connection.dart),
> Commit `5a4eb0a`) — bisher eingebaut in Onboarding + Verbindungs-Editor
> (Profil/Einstellungen), **auf dem Login-Screen aber noch nicht sichtbar**,
> siehe offener Punkt in Abschnitt 10. Nebenbei `tool/build-msix.ps1`
> repariert (falscher Flutter-Pfad, kaputter Signier-Schritt, Passwort nicht
> mehr hart codiert, Commit `d89b27d`). APK/EXE/MSIX neu gebaut mit allen
> drei Fixes.
> **Nutzer-Feedback nach voriger Session — jetzt behoben (diese Session):**
> **"Verbindung ändern" auf dem Login-Screen** ist jetzt immer sichtbar (die
> Sichtbarkeits-Bedingung `!config.hasBakedDefault || config.isUsingOverride`
> wurde entfernt), aber bewusst diskret als kleiner, unauffälliger Text-Link
> statt prominentem Button dargestellt (Rücksprache mit Nutzer:
> "Diskreter Text-Link" gewählt) — [lib/features/auth/login_screen.dart](lib/features/auth/login_screen.dart).
> **Logout über Profilbild:** in das bestehende `PopupMenuButton` in
> [lib/features/profile/profile_switcher.dart](lib/features/profile/profile_switcher.dart)
> wurde unten (mit `PopupMenuDivider`) ein "Abmelden"-Eintrag ergänzt, der
> `authRepositoryProvider.signOut()` aufruft (Rücksprache mit Nutzer: "In
> bestehendes Menü einfügen" statt separatem Profil-Avatar gewählt). Settings
> bleibt zusätzlich als Weg bestehen. `flutter analyze` beider Dateien → keine
> Fehler; `flutter test` → alle 70 Tests grün. **Noch offen:** committen +
> pushen.
> **⚠️ Kritischer Bug gefunden + Doku-Fix (diese Session):** Nutzer meldete,
> dass sein geforktes Repo ("ForkMoneyManager.de") trotz eigenem neuen
> Supabase-Projekt weiterhin **Original-Buchungen zeigte** und Original-Logins
> akzeptierte. Ursache: die committete
> [assets/db_connection/connection.json](assets/db_connection/connection.json)
> (seit Commit `7b95c79`, enthält URL+Key des **Produktiv-Projekts**
> `uaaqehspnlncjzrajfue`) hat **Vorrang vor allem** (Abschnitt 5) und wird bei
> jedem Fork unverändert mitkopiert — die Haupt-`README.md`/`README.en.md`
> erwähnten den nötigen Lösch-Schritt (dokumentiert nur versteckt in
> [assets/db_connection/README.txt](assets/db_connection/README.txt)) nicht
> und behaupteten fälschlich "Ein frischer Fork startet leer". Jeder Fork, der
> die Datei nicht löscht, landet **unsichtbar in der Original-DB** (echtes
> Datenvermischungs-/Datenschutzproblem, kein Cosmetic-Bug). Fix diese Session:
> [README.md](README.md) + [README.en.md](README.en.md) Fork-Anleitung um
> expliziten Lösch-Schritt (jetzt Schritt 2, vor dem Veröffentlichen) +
> Troubleshooting-Hinweis ergänzt. **Noch offen:** der Nutzer muss in seinem
> bereits bestehenden Fork die Datei jetzt noch manuell löschen/ersetzen.
> **Korrektur:** die ursprüngliche Vermutung, `test@gmail.com`/die
> Whitelist-Freischaltung der zweiten Test-Mail seien dabei in der
> Original-DB gelandet, wurde per direkter Prüfung (s. u.) **widerlegt** — in
> der Original-DB existiert weiterhin nur der echte Besitzer-Account, nichts
> aufzuräumen.
> **⚠️ Preset-Kategorien verschwunden — Ursache gefunden + Prod-Fix (diese
> Session):** Nutzer meldete, dass alle Preset-Kategorien (Buchungen-Screen)
> weg waren. Untersuchung via Supabase-MCP direkt gegen die Produktiv-DB
> (`uaaqehspnlncjzrajfue`, nur nach expliziter Nutzer-Freigabe) ergab: die
> Tabelle `categories` war **komplett leer** (0 Zeilen, keine Tombstones) —
> `accounts`=3, `transactions`=2, `recurring_rules`=1, `audit_log`=3, **alle
> Zeitstempel von heute**. Nutzer bestätigte: er hatte bewusst "Datenbank
> leeren" (`admin-wipe-data`) genutzt, um eigene Test-Buchungen zu entfernen —
> **Bug:** `admin_wipe_data()`/`admin_factory_reset()`
> ([supabase/migrations/0023_admin_maintenance.sql](supabase/migrations/0023_admin_maintenance.sql))
> truncateten bislang die komplette `categories`-Tabelle inkl. `is_preset`-Zeilen
> statt nur Testdaten, ohne Re-Seed. Fix:
> [supabase/migrations/0029_wipe_keeps_presets.sql](supabase/migrations/0029_wipe_keeps_presets.sql)
> (neue Helferfunktion `_seed_preset_categories()`, `admin_wipe_data`/
> `admin_factory_reset` löschen jetzt nur `is_preset=false` und säen Presets
> danach neu falls leer — Verhalten entspricht jetzt "Zustand wie
> Neuinstallation"), auch in [supabase/setup.sql](supabase/setup.sql)
> nachgezogen. **Migration mit expliziter Nutzer-Freigabe live auf die
> Produktiv-DB angewendet** + die 31 fehlenden Presets direkt nachgesät
> (verifiziert: `accounts`/`transactions` unverändert bei 3/2, `categories`
> jetzt 31). Für andere Instanzen (inkl. Forks) reicht künftig ein
> `supabase db push`/erneutes `setup.sql`, um Migration 0029 zu bekommen.
> **⚠️ Zugriffskontroll-Lücken gefunden + teilweise gefixt (diese Session):**
> Nutzer fragte zu Recht, ob es ein Problem sei, sich mit einer
> nicht-freigeschalteten E-Mail einloggen zu können, ohne davon zu erfahren.
> Direkte Prüfung der Produktiv-DB (mit Nutzer-Freigabe) ergab: aktuell nur
> **ein** Account (Besitzer, echte E-Mail) und nur `khafi4@gmail.com` in der
> Whitelist (kein Fremdzugriff aktiv) — die vorherige Vermutung eines
> Fremdkontos in der Original-DB war falsch (s. o.). **Strukturell bestätigt
> als echte Lücken:** (1) Die E-Mail-Whitelist
> ([0007_admin_whitelist.sql](supabase/migrations/0007_admin_whitelist.sql))
> greift **nur beim Signup** (DB-Trigger auf `auth.users` insert) — ein
> einmal registrierter Account kann sich **immer** weiter einloggen, auch
> nach Entfernen aus der Whitelist; RLS-Policies sind bewusst
> `for all to authenticated using (true)` (jeder eingeloggte Account hat
> vollen Zugriff auf alle Daten — Kern des "kleine Gruppe teilt alles"-Modells).
> Echter Zugriffsentzug ging bisher nur über Admin → Nutzer → Löschen. (2)
> `public.profiles` speichert keine E-Mail (liegt nur in `auth.users`, für den
> Client nicht abfragbar) — der Admin-Bereich zeigte bisher nur den
> selbstgewählten Anzeigenamen, konnte also nicht zuverlässig zeigen, wer
> hinter einem Account steckt. **Fix (mit Nutzer-Freigabe live auf Prod
> angewendet):**
> [supabase/migrations/0030_admin_list_user_emails.sql](supabase/migrations/0030_admin_list_user_emails.sql)
> (neue admin-only RPC `admin_list_user_emails()`) +
> [lib/data/repositories/admin_repository.dart](lib/data/repositories/admin_repository.dart)
> `fetchUserEmails()` +
> [lib/features/admin/admin_providers.dart](lib/features/admin/admin_providers.dart)
> `userEmailsProvider` +
> [lib/features/admin/admin_screen.dart](lib/features/admin/admin_screen.dart):
> E-Mail wird jetzt im "Nutzer"-Bereich unter dem Namen angezeigt, und beim
> Entfernen einer E-Mail aus der Whitelist prüft `_removeAllowedEmail()`, ob
> dazu schon ein Konto existiert — falls ja, Warndialog mit expliziter Option
> "Auch Konto löschen" (echter Zugriffsentzug), sonst bleibt das Konto
> zugriffsfähig (bewusst, mit Warntext erklärt). `flutter analyze`/`test`
> grün. **Nicht umgesetzt (bewusst nicht gefordert):** proaktive
> Benachrichtigung bei Neuregistrierung (z. B. E-Mail an Besitzer) — größeres
> Feature, bräuchte einen E-Mail-Versanddienst; als Idee notiert, falls
> gewünscht.
> **Vier offene ToDos abgearbeitet (diese Session, je einzeln vom Nutzer
> freigegeben):**
> 1. **Archivierungs-Deployment verifiziert** (nur lesend gegen Prod-DB) —
>    siehe Abschnitt 11, vollständig live, nur noch ungetestet in der Praxis.
> 2. **"Passwort ändern" für eingeloggte Nutzer** in
>    [lib/features/profile/profile_screen.dart](lib/features/profile/profile_screen.dart)
>    ergänzt (Dialog, nutzt bestehendes `AuthRepository.updatePassword()`).
> 3. **Service-Worker für Web/PWA deaktiviert** (vorsorglicher Fix gegen das
>    iPhone-Login-Caching-Problem aus Abschnitt 10, Ursache nicht bestätigt,
>    aber bekannte Klasse von Flutter-Web-PWA-Bug): `--pwa-strategy=none` in
>    [.github/workflows/deploy-web.yml](.github/workflows/deploy-web.yml) —
>    verifiziert im lokalen Build, dass `flutter_bootstrap.js` danach
>    `_flutter.loader.load()` **ohne** `serviceWorker`-Config aufruft, also
>    gar keine Registrierung mehr stattfindet. Die App ist ohnehin auf
>    Live-Sync angewiesen, kein Offline-Feature verloren.
> 4. **Restliche deutsche Texte lokalisiert:** Insight-Karten
>    ([insights_providers.dart](lib/features/insights/insights_providers.dart)),
>    Erinnerungs-Texte
>    ([reminders_providers.dart](lib/features/reminders/reminders_providers.dart))
>    und PDF-Export
>    ([pdf_export.dart](lib/features/export/pdf_export.dart), Signatur um
>    `headers`/`emptyText`/`incomeLabel`/`expenseLabel`/`balanceLabel`/
>    `pageLabel` erweitert, beide Call-Sites in `export_screen.dart` +
>    `all_transactions_screen.dart` angepasst) — alle über neue Getter/Funktionen
>    in [app_localizations.dart](lib/l10n/app_localizations.dart) (Präfixe
>    `ins`/`rem`/`pdf`). Damit sind laut Abschnitt 6 jetzt **alle** Nutzer-Screens
>    inkl. generierter Texte lokalisiert (nur noch CSV-Format, `period_filter.dart`
>    [ungenutzt] und ein kontextloser Fallback bleiben bewusst deutsch).
>
> `flutter analyze` + `flutter test` (70/70) für alle vier Punkte grün.
> **⚠️ CI-Format-Fix (diese Session):** `dart format --set-exit-if-changed`
> schlug in der Web-Deploy-Pipeline fehl (3 der oben geänderten Dateien nicht
> `dart format`-konform). Mit `dart format` (nicht `flutter format` — das
> Kommando existiert in dieser Flutter-Version nicht mehr) neu formatiert;
> lokal exakt denselben CI-Befehl nachgestellt → 0 Dateien geändert. Nur
> Whitespace/Zeilenumbrüche, keine Logikänderung; `flutter test` weiterhin
> 70/70 grün.
> **Auto-Sync für Forks (diese Session):** Nutzer möchte, dass unabhängige
> Dritte selbst forken/hosten können und trotzdem künftige Bugfixes/Features
> automatisch bekommen, ohne manuell git-Befehle auszuführen. Neuer Workflow
> [.github/workflows/sync-upstream.yml](.github/workflows/sync-upstream.yml):
> läuft **wöchentlich (montags) + manuell auslösbar** in jedem Fork (im
> Original-Repo selbst übersprungen, `if: github.repository !=
> 'LevelADude/Money-Manager'`), merged `upstream/main` und pusht bei
> sauberem Merge direkt (nächster Deploy-Web-Lauf zieht nach) — bei echtem
> Konflikt wird **keinesfalls still gemergt**, sondern eine PR zum manuellen
> Prüfen eröffnet. [.gitattributes](.gitattributes) mit `assets/db_connection/
> connection.json merge=ours` schützt die instanzeigene DB-Verbindung
> **strukturell** davor, jemals durch einen Auto-Sync überschrieben zu werden
> (der "ours"-Treiber wird im Workflow selbst per `git config
> merge.ours.driver true` registriert, da kein Git-Standardtreiber). Der
> Workflow liegt im Hauptrepo, kommt also mit **jedem künftigen Fork
> automatisch mit** — nur bereits bestehende Forks (aktuell nur die eigenen
> Test-Instanzen des Nutzers) müssten ihn einmalig manuell nachziehen. README
> (DE/EN) um Abschnitt "🔄 Updates automatisch erhalten" ergänzt. **Bewusst
> nicht umgesetzt:** Sync auf Basis von Git-Tags/Releases (Nutzer wollte
> explizit jeden main-Commit sofort, nicht nur getaggte Stände).
> **Neues Feature: Freitext-Bezeichnung pro Teilsumme (diese Session, per Plan
> Mode geplant + freigegeben):** Nutzer wollte eine Buchung in Teilsummen mit
> eigener Bezeichnung aufteilen können (z. B. "12 € Produkt A"). Fund bei der
> Recherche: Die "Aufteilen"-Funktion existierte schon (`transaction_splits`:
> Kategorie + Betrag + ein `note`-Feld) — nur wurde `note` in der UI nirgends
> befüllt oder angezeigt (immer hart `''`). **Keine neue Migration nötig.** Fix
> in [lib/features/transactions/transaction_form_screen.dart](lib/features/transactions/transaction_form_screen.dart):
> `_SplitRow` um `noteCtrl` erweitert, neues Freitext-Feld pro Split-Zeile in
> `_buildSplitEditor()`, `_prefillSplits()` lädt jetzt auch `note`, beide
> Speicherpfade (`_save()`, `_duplicate()`) reichen `noteCtrl.text` durch statt
> `''`. Neue Strings `splitItemNoteLabel` in
> [app_localizations.dart](lib/l10n/app_localizations.dart);
> `splitMultiple`-Wortlaut von "Kategorien" auf "Posten" verallgemeinert. Mit
> Nutzer geklärt: Posten-Details bleiben auf das Bearbeiten-Formular
> beschränkt (kein Preview in der Buchungsliste), Kategorie pro Posten bleibt
> optional wie bisher. `dart format` + `flutter test` (70/70) grün — `flutter
> analyze`/`dart analyze` hingen in dieser Session wiederholt (Umgebungsproblem,
> nicht Code-bezogen) und wurden abgebrochen, siehe Abschnitt 9. **Live-Test im
> Preview-Browser nicht abschließend möglich:** `.claude/launch.json` (neu,
> `flutter run -d web-server`) + Claude-Preview-Tool aufgesetzt; App startete
> nachweislich (Konsole zeigt "Supabase init completed", Boot-Screen
> verschwand), aber Screenshot/Accessibility-Snapshot des Canvas-gerenderten
> Flutter-Web-Inhalts blieben in diesem Sandbox-Tooling leer/timeout (Flutter
> Web exponiert ohne aktivierte Semantics keine anklickbaren DOM-Elemente).
> **Empfehlung: kurz manuell gegentesten** (`pwsh tool/run-windows.ps1` oder
> im Browser), bevor es als vollständig verifiziert gilt.
> **Neues Feature: Quick-Toggle „Beträge verbergen" (diese Session):** Nutzer
> wollte einen schnellen Ein/Aus-Schalter für Geldbeträge direkt auf Konten-
> und Buchungen-Screen (statt nur in den Einstellungen), plus `*` statt
> Punkte als Platzhalter. **Fund bei der Recherche:** Die Grundfunktion
> existierte schon (`AppSettings.hideAmounts` + `MoneyText`-Widget, zeigte
> „••••"), nur ohne Schnellzugriff außerhalb der Einstellungen — und die
> Summenkarten (Einnahmen/Ausgaben/Saldo) auf dem Buchungen-Screen
> (`_SumBox` in `all_transactions_screen.dart`) nutzten noch rohes
> `formatCents()` statt `MoneyText`, ignorierten die Einstellung also
> versehentlich. Fix: [lib/shared/money_text.dart](lib/shared/money_text.dart)
> zeigt jetzt „****"; neues wiederverwendbares
> [lib/shared/hide_amounts_toggle.dart](lib/shared/hide_amounts_toggle.dart)
> (Augen-Icon, Zustand spiegelt `hideAmounts`, tauscht direkt
> `settingsProvider.notifier.setHideAmounts()`) als erste AppBar-Aktion in
> [accounts_screen.dart](lib/features/accounts/accounts_screen.dart) und
> [all_transactions_screen.dart](lib/features/transactions/all_transactions_screen.dart)
> ergänzt; `_SumBox` dort auf `MoneyText` umgestellt (schließt die
> Sichtbarkeits-Lücke). PDF-Export-Summen (`_sharePeriodPdf`) bewusst
> **nicht** an `hideAmounts` gekoppelt — ein bewusst exportiertes PDF soll
> lesbar bleiben, das ist kein Bildschirm-Privatsphäre-Fall. Neuer String
> `showAmounts` in [app_localizations.dart](lib/l10n/app_localizations.dart).
> `dart format` + `flutter test` (70/70) grün. **Live-Test im
> Preview-Browser diesmal nicht möglich** (App blieb im Boot-Screen hängen,
> anders als beim vorigen Feature in dieser Session) — Ursache vermutlich
> weiterhin das in Abschnitt 9 dokumentierte Sandbox-Tooling-Problem, nicht
> der neue Code. **Manuell gegentesten empfohlen.**
> **Davor:** Archivierung alter Jahre nach GitHub (Commit `94189e2`) und DB
> fest über committete `assets/db_connection/connection.json` gebunden
> (Abschnitt 5) — beide laut Git-Historie bereits committet, dieser Stand war
> im Dokument noch nicht nachgezogen.

</details>

Gemeinsame Finanz-Buchhaltung für eine kleine Gruppe (Windows + Android, dazu
Web), Daten-Sync über **Supabase**. Flutter-App, zweisprachig **DE/EN**.

Dieses Dokument ist der Einstieg für eine neue Person (oder eine neue
Session). Tieferes liegt in [README.md](README.md), [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md)
und [supabase/README.md](supabase/README.md).

---

## 1. Schnellstart (Build & Run)

**Flutter SDK liegt unter `C:\dev\flutter` und ist NICHT in PATH.** Immer über
den vollen Pfad aufrufen:

```bash
"C:/dev/flutter/bin/flutter.bat" pub get
"C:/dev/flutter/bin/flutter.bat" analyze lib
"C:/dev/flutter/bin/flutter.bat" build web --release
```

Die App braucht zur Laufzeit Supabase-Zugangsdaten. Diese stehen **nicht** im
Quellcode (siehe Abschnitt 5). Lokal kommen sie aus `env.json`
(gitignored; Vorlage: [env.example.json](env.example.json)):

```bash
# Windows-Desktop starten (übergibt env.json als --dart-define-from-file)
pwsh tool/run-windows.ps1
# Android
pwsh tool/run-android.ps1
# Windows-MSIX bauen
pwsh tool/build-msix.ps1
```

Ohne Zugangsdaten startet die App **leer** und zeigt das Onboarding (das ist
gewollt — siehe Self-Hosting).

---

## 2. Tech-Stack

| | |
|---|---|
| Flutter SDK | 3.44.2 (`C:\dev\flutter`), Dart `^3.12.2` |
| State | `flutter_riverpod` ^3.3.2 — **Riverpod 3.x**: `Notifier`/`NotifierProvider`, **kein** `StateProvider` (entfernt) |
| Routing | `go_router` ^17.3.0 ([lib/core/router.dart](lib/core/router.dart)) |
| Backend | `supabase_flutter` ^2.15.0 (Postgres + Storage + Edge Functions + RLS) |
| OCR | `google_mlkit_text_recognition` ^0.15.0 — **nur Android**, via conditional import vom Web-Build ferngehalten |
| PDF | `pdf` + `printing` |
| Sonstiges | `intl`, `shared_preferences`, `share_plus`, `image`/`image_picker`, `crypto` |
| Lokalisierung | **hand-gepflegt**, kein gen-l10n/ARB (siehe Abschnitt 6) |

Plattformen: **Windows** (primär), **Android**, **Web** (GitHub Pages).

---

## 3. Architektur

Schichten unter `lib/`:

- `config/` — `AppConfig` (Laufzeit-Override der DB-Verbindung pro Gerät),
  `SupabaseConfig` (Build-Zeit-Defaults, bewusst leer).
- `data/models/` — reine Datenmodelle (Account, AppTransaction, Budget,
  RecurringRule, SavingsGoal, Category, Profile, …).
- `data/repositories/` — Supabase-Zugriff (eine Repo-Klasse pro Domäne).
- `data/local/app_cache.dart` — lokaler JSON-Cache in SharedPreferences
  (pro Gerät, **liegt nicht im Repo**).
- `features/<bereich>/` — pro Feature ein Ordner mit `*_screen.dart` (UI) +
  `*_providers.dart` (Riverpod-Provider). Bereiche u. a.: accounts,
  transactions (+ `ocr/`), statistics, budgets, savings, categories, recurring,
  planning, projects, debts, settle, sharing, currency, export, backup,
  insights, reminders, activity, search, admin, profile, auth, onboarding,
  settings.
- `core/` — `router.dart`, `main_scaffold.dart` (Bottom-Nav), `theme.dart`.
- `shared/` — wiederverwendbare Widgets/Helfer (`money.dart`/`money_text.dart`,
  `calculator_sheet.dart`, `mini_line_chart.dart`, `image_compress.dart`, …).
- `l10n/app_localizations.dart` — zentrale Übersetzungstabelle.

Start-Sequenz: [lib/main.dart](lib/main.dart) `_Bootstrap` → prüft Konfiguration →
initialisiert Supabase → `MoneyManagerApp` ([lib/app.dart](lib/app.dart)); ist
nichts konfiguriert, wird stattdessen das Onboarding gezeigt (eigene
`MaterialApp`, eigene Locale-Verdrahtung).

---

## 4. Backend / Supabase

- **Migrationen:** `supabase/migrations/0001…0030_*.sql`. `supabase/setup.sql`
  ist das **Komplett-Setup** (alle Tabellen + RLS + Storage), das im Onboarding
  zum Kopieren angeboten wird (als Asset gebündelt).
- **Edge Functions** (`supabase/functions/`, Deno):
  `admin-delete-user`, `admin-wipe-data`, `admin-factory-reset`.
- **Rollen:** erste registrierte E-Mail wird **Besitzer** (`is_owner`,
  Migration 0022); Admin-Wartung in 0023. Zugriff zusätzlich über
  E-Mail-Whitelist (0007) + RLS gesteuert.
- **Produktiv-Projekt:** Supabase `uaaqehspnlncjzrajfue` (Migrationen 0001–0030
  dort angewandt, Stand 2026-07-02).

⚠️ Die zerstörerischen Functions `admin-wipe-data` / `admin-factory-reset`
**niemals** gegen die Produktiv-DB ausführen.

---

## 5. Self-Hosting & Zugangsdaten (WICHTIG)

Auflösungsreihenfolge der Verbindung ([lib/config/app_config.dart](lib/config/app_config.dart)),
höchste zuerst:

1. **Pro-Gerät-Override** (SharedPreferences) — „Datenbank-Verbindung ändern",
   erreichbar aus Profil und Login.
2. **Committete Repo-Datei `assets/db_connection/connection.json`** (JSON
   `{url, anonKey}`) — beim Start via `rootBundle` geladen
   ([lib/config/db_connection_file.dart](lib/config/db_connection_file.dart)),
   funktioniert auf allen Plattformen inkl. Web. **Das ist die primäre Bindung:**
   vorhanden+gültig → jedes Gerät verbindet automatisch, kein Onboarding. Der
   Ordner wird als Ganzes gebündelt (+ `README.txt`), damit das Löschen **nur**
   von `connection.json` den Build NICHT bricht → fällt dann auf Onboarding
   zurück. So trennt sich ein Fork von der DB.
3. **dart-define** (`lib/config/supabase_config.dart`, leere committete
   Defaults): lokal `env.json` (gitignored) via `--dart-define-from-file=env.json`
   (`tool/run-*.ps1`); Web (GitHub Pages) Repo-Secrets `SUPABASE_URL` +
   `SUPABASE_ANON_KEY` im Deploy-Workflow ([.github/workflows/deploy-web.yml](.github/workflows/deploy-web.yml)).
   **Jetzt optional**, da die committete Datei Vorrang hat.
4. Nichts gesetzt → Onboarding (neue DB oder bestehende verbinden).

Die committete `connection.json` enthält URL + Publishable-Key der Besitzer-DB —
das ist in Ordnung, weil beide **öffentliche Client-Werte** sind (stecken ohnehin
im Web-Bundle); der Schutz läuft über **RLS + E-Mail-Whitelist**, nicht über
Geheimhaltung. Trotzdem: **`env.json` weiterhin nicht committen.**

**Forks bekommen Updates jetzt automatisch:**
[.github/workflows/sync-upstream.yml](.github/workflows/sync-upstream.yml)
synct wöchentlich (+ manuell auslösbar) mit diesem Original-Repo; bei
sauberem Merge direkter Push, bei Konflikt eine PR statt stillem Merge.
[.gitattributes](.gitattributes) (`merge=ours` für `connection.json`)
schützt die instanzeigene DB-Verbindung strukturell davor, dabei je
überschrieben zu werden. Läuft nur in Forks (im Original-Repo übersprungen).

---

## 6. Lokalisierung (DE/EN) — abgeschlossen

**Hand-gepflegt, kein Codegen.** [lib/l10n/app_localizations.dart](lib/l10n/app_localizations.dart)
hält eine Getter-Tabelle über `String _t(String de, String en)` plus einen
`LocalizationsDelegate`. `flutter_localizations` liefert Material/Datums-L10n.

- Sprache in den Einstellungen umschaltbar (`AppSettings.localeCode`, Pref-Key
  `settings_locale`, Default `de`). Umschalten ist sofort wirksam.
- **Stand:** Alle Nutzer-Screens unter `lib/features/**` sind lokalisiert
  (Batch 1–8 abgeschlossen). Auch Onboarding/Ladebildschirm (laufen vor der
  Riverpod-Init) bekommen in `main.dart` Delegates + Locale (direkt aus Prefs).
- **Neuen Text übersetzen:** Getter `String get x => _t('De','En');` ergänzen,
  im Screen `final l = AppLocalizations.of(context);` und `l.x` nutzen.
- Zentrale Helfer wiederverwenden statt Modell-`.label`: `accountType(...)`,
  `transactionType(...)`, `intervalUnitLabel(...)`, `everyInterval(...)`,
  `monthName/monthAbbr/weekdayAbbr`, `dayHeader(...)`, `auditAction(...)`.

- **Auch Provider (kein `BuildContext`) lokalisiert:** `AppLocalizations` hat
  einen öffentlichen Konstruktor (`AppLocalizations(Locale(...))`), daher in
  `insights_providers.dart`/`reminders_providers.dart` per
  `AppLocalizations(Locale(ref.watch(settingsProvider.select((s) => s.localeCode))))`
  nutzbar, ganz ohne Context. Muster für künftige Provider-seitige Texte.

**Bewusst deutsch geblieben (Daten/Format, keine UI-Chrome):**
- CSV-Export/-Import-Format (Spalten `Datum;Typ;Betrag;…`) — für Round-Trip-Import.
- `period_filter.dart` Extension-Labels (`.label`/`labelFor`) — **ungenutzt**
  (Statistik hat eigene lokalisierte Helfer).
- Ein Provider-Fallback `'Unbekannt'` in `person_filter.dart` (kein `context`).
- Geldformat bleibt `de_DE`; numerische Datumsangaben bleiben `dd.MM.yyyy`.

---

## 7. Nennenswerte Features

- Konten (mehrere Typen, Archiv, Sortierung, Gemeinschaftskonten/Freigaben).
- Buchungen: Einnahme/Ausgabe/Übertrag, Splits (**inkl. Freitext-Bezeichnung
  pro Posten**, z. B. "12 € Produkt A"), Vorlagen, Tags, Beleg-Foto
  (**Kompression vor Upload**, [shared/image_compress.dart](lib/shared/image_compress.dart)),
  Papierkorb (30 Tage, Retention-Cleanup-Migration 0021).
- **Beträge verbergen** (Privatsphäre): Quick-Toggle (Augen-Icon) direkt in
  der AppBar von Konten- und Buchungen-Screen
  ([shared/hide_amounts_toggle.dart](lib/shared/hide_amounts_toggle.dart)),
  zeigt `****` statt Beträgen ([shared/money_text.dart](lib/shared/money_text.dart));
  zusätzlich in Einstellungen umschaltbar. Gilt bewusst nicht für PDF-Exporte.
- **OCR (nur Android, ML Kit, on-device):** Beleg-Foto füllt Betrag/Datum/Titel
  vor. Hinter conditional import — darf **nie** in den Web-Build.
- **Insights** (lokal, regelbasiert): Monatsvergleich, Ausreißer, Sparquote,
  Abo-Erkennung, Hochrechnung; Monat/Jahr-Umschalter, antippbare Karten.
  **Voll privat — kein Cloud-LLM.**
- Budgets, Sparziele/Töpfe (inkl. Rundungs-Sparen), Daueraufträge, erkannte
  Abos, Statistik (Charts/Heatmap), Planung (Verfügbar & Fixkosten, Cashflow,
  Was-wäre-wenn), Schulden, Projekte/Reisen (Tags), Ausgleich (wer schuldet
  wem), Wechselkurse, Export (CSV/PDF), Import (CSV), Backup (JSON),
  Erinnerungen/Streak, Aktivitäts-Feed, Suche, App-Sperre (PIN),
  Verwaltung/Admin (Speicher, Whitelist, Rollen, Wartung).

---

## 8. Constraints (nicht verletzen)

- **KEIN kostenpflichtiges LLM.** Bewusste Endentscheidung des Nutzers:
  Insights/OCR bleiben 100 % lokal & privat. Auch Gemini-Free-Tier wurde wegen
  Trainings-/Datenschutzbedingungen abgelehnt.
- **Supabase-Creds nie im committeten Code** (`env.json` gitignored;
  Web über GitHub-Secrets).
- **Zerstörerische Edge Functions** nie gegen Produktiv-DB ausführen.
- ML Kit darf **nie** in den Web-Build gezogen werden → der `flutter build web`
  ist der entscheidende Gegen-Check.

---

## 9. Dev-Fallen (real aufgetreten)

- **`windows/flutter/generated_*`** erscheinen nach jedem `pub get` als
  „geändert" — ist nur LF→CRLF-Rauschen. Vor dem Commit verwerfen:
  `git checkout -- windows/flutter/generated_*`.
- **PowerShell-Here-Strings:** Nichts hinter das schließende `'@` hängen.
  `'@` allein auf Spalte 0, `git push` als **separaten** Aufruf.
- **Riverpod 3:** `StateProvider` existiert nicht mehr → `Notifier` +
  `NotifierProvider` mit `set(...)`-Methode.
- **Onboarding läuft vor Riverpod-Init** → eigene `MaterialApp` mit eigener
  Locale/Delegate-Verdrahtung; `AppLocalizations.of(context)` würde dort sonst
  null liefern.
- Commits/Pushes nur auf ausdrückliche Anweisung; Branch ist `main`
  (Git-User `LevelADude`).
- **`flutter analyze`/`dart analyze` hängen in dieser Dev-Umgebung
  wiederholt** (mehrfach beobachtet, mehrere Sessions: läuft minutenlang ohne
  Ausgabe, `TaskStop` + Neustart hilft manchmal, manchmal auch nicht).
  Umgebungsproblem, kein Code-Fehler — als Ersatz-Verifikation `dart format
  --output=none --set-exit-if-changed` (schnell, zuverlässig) + `flutter test`
  nutzen, wenn `analyze` hängt.
- **Claude-Preview-Tool + dieses Flutter-Web (CanvasKit-Renderer):**
  Screenshot/Accessibility-Snapshot bleiben oft leer/timeout, obwohl die App
  laut Konsole/DOM (`#boot`-Element verschwunden, "Supabase init completed")
  tatsächlich läuft — Flutter Web exponiert ohne aktivierte Semantics keine
  per CSS ansprechbaren Elemente. **Funktionierender Workaround (2026-07-03
  verifiziert):** per `preview_eval` auf dem `flt-semantics-placeholder` ein
  `MouseEvent('click')` dispatchen, ein paar Sekunden warten, dann liefern
  `flt-semantics`-Knoten `aria-label`s und Rollen (Login-Screen so überprüft).
  Geduld beim Start: der Debug-Build braucht ~2–3 Min., bis `#boot`
  verschwindet — vorher sieht es wie ein Hänger aus.

---

## 10. Offene Punkte / als Nächstes

**🚀 Finalisierungs-Phase — LÄUFT.** Schritte 1–3 (Features antesten,
Toter-Code-Suche, `flutter analyze`) sind erledigt — Ergebnisse und die
offene Verbesserungsliste stehen im Zwischenstand-Block ganz oben. Schritt 4:
Liste mit dem Nutzer priorisieren, dann erst umsetzen.

**Wirklich noch offen (nicht Teil der Finalisierung, eigenständige Punkte):**

- ⭐ **Login schlägt auf iPhone/Safari fehl** (iPad geht, gleiche
  Zugangsdaten). **Root-Cause weiterhin nicht bestätigt.** Vorsorglicher Fix
  bereits drin: Service-Worker für den Web-Build deaktiviert
  (`--pwa-strategy=none`, [deploy-web.yml](.github/workflows/deploy-web.yml)) —
  häufigste Ursache ("altes Gerät hängt an altem Build") damit ausgeschlossen.
  Tritt es weiterhin auf: im Supabase-Dashboard **Authentication → Logs** den
  genauen Fehler des fehlgeschlagenen Versuchs ansehen.
- ⭐ **Proaktive Benachrichtigung bei Neuregistrierung** — nur als Idee
  notiert, nicht gefordert/umgesetzt. Bräuchte E-Mail-Versanddienst (z. B.
  Resend) + Supabase Auth-Webhook — vor Umsetzung mit Nutzer klären
  (Kosten/Datenschutz, wie bei Abschnitt 8/LLM-Entscheidung).
- **Für Forks/andere Instanzen (nicht das Original) noch nachzuziehen, falls
  sie schon vor dieser Session bestanden:** Migrationen 0029 (Presets-Fix)
  und 0030 (E-Mail-Sichtbarkeit) per `setup.sql`/`supabase db push`
  einspielen — der neue Auto-Sync-Workflow (Abschnitt 5) übernimmt das ab
  jetzt automatisch für zukünftige Änderungen.
- **Archivierung:** Deployment vollständig live (Migrationen, Edge Function,
  Repo verbunden), aber **0 archivierte Jahre** — End-to-End-Test
  (archivieren → ansehen → de-archivieren) mit echten Daten steht noch aus.
- ⭐ **Splits-Notiz + Beträge-Toggle: nur noch der eingeloggte Klick-Test
  offen.** Beide Features sind seit 2026-07-03 per Widget-/Unit-Tests
  abgedeckt (`test/hide_amounts_test.dart`, `test/split_note_test.dart`),
  App-Boot + Login-Screen im Preview verifiziert — nur der Schritt hinter
  dem Login braucht die echten Zugangsdaten des Nutzers (2 Minuten:
  Augen-Icon auf Konten/Buchungen antippen; eine Buchung aufteilen und
  einer Teilsumme einen Text geben, speichern, wieder öffnen).
- `verify`/manuelles Testen auf echtem Android-Gerät (OCR, Beleg-Flow) steht
  weiterhin beim Nutzer aus (hier kein Gerät verfügbar).

---

## 11. Archivierung alter Jahre nach GitHub — IMPLEMENTIERT + DEPLOYED (0 Jahre genutzt)

**Ziel des Nutzers:** Alte Buchungen aus der Supabase-DB **nach GitHub
auslagern**, um DB-/Storage-Speicher freizugeben. Ausgelagerte Jahre bleiben in
der App **sichtbar, aber read-only** und zählen nicht mehr zu Statistik/Budgets.

### 11.0 Umsetzungsstand (2026-06-22)

**Geklärte Entscheidungen (11.4 + Nachschärfung):** separates **privates**
Daten-Repo (App-Repo bleibt öffentlich → github.io frei), **verschlüsselt**
(AES-256-GCM), Marker + Carry-over je Konto in DB-Tabelle `archived_years`,
Belege mit-exportiert, **de-archivierbar**. **Wichtig:** Das Archiv-Repo ist
**nicht** fest verdrahtet, sondern **pro Instanz in der App einrichtbar** (Owner
gibt Repo + Token an) — Repo/Token/Schlüssel liegen **serverseitig in Supabase**
(`archive_config`), nicht als Function-Secret. Geltungsbereich: **ein Repo pro
Instanz**, nicht pro Nutzer.

**Implementiert & verifiziert (Code-Seite):**
- Migrationen [0024_archived_years.sql](supabase/migrations/0024_archived_years.sql)
  (`archived_years` + RLS + RPC `purge_year_data`, Audit-Trigger via GUC
  `app.skip_audit` ausgesetzt) und [0025_archive_config.sql](supabase/migrations/0025_archive_config.sql)
  (`archive_config` Single-Row + RPCs `get/set/clear_archive_config`, Token/Key
  nie an den Client); beide auch in [supabase/setup.sql](supabase/setup.sql).
- Edge Function [supabase/functions/archive-proxy/index.ts](supabase/functions/archive-proxy/index.ts):
  liest Repo/Token/Key aus `archive_config` (service_role), `write/read/list/delete`,
  AES-256-GCM, GitHub Contents API. **read/list** für alle Angemeldeten,
  **write/delete** nur Admin.
- Dart: Modelle [archived_year.dart](lib/data/models/archived_year.dart) +
  [archive_config_status.dart](lib/data/models/archive_config_status.dart),
  [archive_repository.dart](lib/data/repositories/archive_repository.dart)
  (archivieren/laden/de-archivieren + Config get/set/clear + Key-Gen +
  Repo-Normalisierung; Belege base64 inline),
  [lib/features/archive/](lib/features/archive/) (Provider + `archive_screen.dart`
  [auf Config gated] + `archived_year_screen.dart` + `archive_setup_screen.dart`).
- Carry-over fließt in Salden/Vermögen ([account_providers.dart](lib/features/accounts/account_providers.dart)).
- Route `/more/archive`; Einstieg „Mehr"-Menü (alle) + Admin-Screen.
- Strings in [app_localizations.dart](lib/l10n/app_localizations.dart);
  Setup-Anleitung in [README.md](README.md).

**Deployment-Status (verifiziert 2026-07-02 direkt gegen Prod-DB, nur
lesend):** Schritte 1–5 ✅ **erledigt** — Migrationen 0024+0025 angewendet,
`archive-proxy` ACTIVE, `archive_config` zeigt auf
`LevelADude/Money-Manager-Archieve` (Stand 22.06.2026). Nur noch offen:
6. End-to-End mit Owner-Konto testen (archivieren → ansehen → de-archivieren)
   — bisher 0 archivierte Jahre, Feature ungetestet in der Praxis.

**Hinweis Belege/Größe:** Eine Jahresdatei enthält die Belege inline (base64);
der Proxy liest große Dateien über `Accept: application/vnd.github.raw` (bis
100 MB). Bei sehr vielen Belegen pro Jahr ggf. später auf separate Beleg-Dateien
umstellen.

### 11.1 Anforderungen (wörtlich vom Nutzer, verbindlich)

1. **Export nach GitHub**, um DB-Speicher freizubekommen.
2. **Speicherort:** ein **klar beschrifteter Ordner, frontal/Top-Level** (NICHT in
   verschachtelten Unterordnern). Pro **exportiertem Jahr eine Datei**; darin die
   Daten dieses Jahres.
3. **Jahres-Auswahl beim Speichern:** Option, gezielt die zu exportierenden Jahre
   auszuwählen.
4. **Nach Export:** Daten bleiben in der App **einsehbar**, aber **nicht mehr
   bearbeitbar** und **fließen nicht mehr in Statistiken** ein.
5. **Warnung anzeigen:** dass Bearbeiten/Statistik für diesen Bereich danach nicht
   mehr funktionieren, und dass man das **nur tun soll, wenn der Speicher fast
   voll ist**.

### 11.2 Relevante Stellen im Code

- Buchungen: Tabelle `transactions`, Modell [lib/data/models/app_transaction.dart](lib/data/models/app_transaction.dart),
  Zugriff [lib/data/repositories/transaction_repository.dart](lib/data/repositories/transaction_repository.dart)
  (zentral `watchAll()` → Cache-then-Stream, sortiert nach `occurred_on`,
  `deleted_at == null`). Felder u. a. `occurred_on` (Jahr daraus), `amount_cents`,
  `account_id`, `category_id`, `transfer_account_id`, `tags`, `receipt_path`.
- Abhängige Daten eines Jahres, die mit-exportiert/mit-gelöscht werden müssen:
  **Splits** (`transaction_splits`, FK-Cascade), **Kommentare**
  (`transaction_comments`), **Belege** (`receipt_path` → Supabase Storage — das
  ist oft der größte Speicherfresser!).
- Statistik baut auf den Buchungen auf: [lib/features/statistics/statistics_providers.dart](lib/features/statistics/statistics_providers.dart),
  Insights [lib/features/insights/insights_providers.dart](lib/features/insights/insights_providers.dart),
  Budgets, Konto-Salden (`account_providers.dart`). **Alle** müssen die
  archivierten Buchungen ausschließen (kommen ohnehin nicht mehr aus `watchAll()`,
  wenn sie aus der DB gelöscht sind — aber die read-only-Ansicht lädt sie separat).
- Bestehendes Vorbild für Export/Format: `features/export/` (CSV/PDF),
  `features/backup/` (JSON-Backup) — Format/Helfer wiederverwenden.
- Admin/Speicher-Anzeige: `features/admin/` (`get_storage_stats`) — guter Ort für
  Einstieg + die „Speicher fast voll"-Warnung.

### 11.3 Vorgeschlagener technischer Plan

**Datenfluss pro ausgewähltem Jahr:**
1. Alle Buchungen (+ Splits/Kommentare, ggf. Belege) des Jahres aus Supabase
   lesen, als **JSON** serialisieren (round-trip-fähig, Quelle der Wahrheit).
2. Datei nach GitHub schreiben: Top-Level-Ordner, z. B. `archive/2022.json`
   (klar beschriftet, frontal). Plus eine `archive/index.json`, die festhält,
   welche Jahre ausgelagert sind (+ pro Konto den **Carry-over-Saldo**, siehe
   ⚠️ unten).
3. Nach **bestätigtem** Push: die Zeilen des Jahres aus Supabase löschen
   (`transactions` endgültig, abhängige via Cascade; Belege aus Storage löschen).
   → gibt Speicher frei.
4. App zeigt archivierte Jahre über einen **getrennten, read-only Provider**, der
   die GitHub-Dateien lädt und cached — strikt getrennt vom bearbeitbaren
   `watchAll()`-Strom und von allen Statistik-/Budget-/Saldo-Aggregaten.

**GitHub-Zugriff:** Contents API (PUT/GET). Token NICHT in den Client (v. a.
Web-Build = öffentlich!). Empfohlen: **Supabase Edge Function als Proxy** mit dem
GitHub-Token als Server-Secret — passt zum bestehenden Edge-Function-Muster
(`supabase/functions/`). Lesen der archivierten Dateien kann direkt erfolgen,
wenn das Repo öffentlich ist (sonst auch über den Proxy).

**UI:** Einstieg unter Verwaltung/Admin oder Export. Schritte: (a) Liste der
Jahre mit Buchungsanzahl/Größe + Checkboxen; (b) **Warn-Dialog** (Text aus 11.1
Punkt 5) mit ausdrücklicher Bestätigung; (c) Fortschritt; (d) Erfolg. Archivierte
Buchungen in Listen/Detail mit „Archiviert"-Badge, ohne Bearbeiten/Löschen-Aktionen.
Neue Strings über `_t('de','en')` in [lib/l10n/app_localizations.dart](lib/l10n/app_localizations.dart).

### 11.4 ⚠️ Offene Entscheidungen — VOR dem Coden mit dem Nutzer klären

1. **Repo-Sichtbarkeit / Datenschutz (kritisch):** Ist das Ziel-Repo **öffentlich**,
   sind die exportierten **Finanzdaten öffentlich lesbar**. Optionen: separates
   **privates** Daten-Repo, oder Verschlüsselung der Jahresdateien, oder klare
   Nutzer-Zustimmung. Muss entschieden werden.
2. **Welches Repo / welcher Ordner genau?** Dasselbe `money-manager`-Repo
   (`/archive/`) oder ein dediziertes Daten-Repo? Token-Scope danach wählen.
3. **Kontosalden:** Werden alte Buchungen aus der DB entfernt, fehlt der laufende
   Kontostand seinen Anfangsbestand. „Fließt nicht in Statistik" ≠ „Saldo ist
   egal". Vorschlag: beim Archivieren pro Konto einen **Carry-over/Eröffnungssaldo**
   festschreiben (Summe der ausgelagerten Buchungen), in `index.json` oder einer
   kleinen DB-Tabelle. Bestätigen lassen.
4. **Belege/Storage mit-exportieren?** Belege liegen in Supabase Storage und sind
   meist der größte Speicheranteil — sinnvollerweise mit auslagern (als Teil der
   Jahresdatei oder in `archive/2022/receipts/`). Bestätigen.
5. **Reversibel?** Ein Jahr wieder zurückholen (de-archivieren) als Sicherheitsnetz?
   Nicht gefordert, aber empfehlenswert.
6. **Marker-Speicherort:** `archive/index.json` auf GitHub (hält DB-Footprint
   minimal, passt zum Ziel) vs. kleine Supabase-Tabelle `archived_years`.

### 11.5 Constraints beachten

Punkt 8 dieses Dokuments gilt weiter (kein kostenpflichtiges LLM; Creds/Token nie
im committeten Client-Code; ML Kit nie in den Web-Build). Commits/Pushes nur auf
ausdrückliche Anweisung.

---

## Verifikation des aktuellen Stands

**Stand 2026-07-03 nachmittags (Finalisierung, Schritte 1–3):**
`flutter analyze lib test` → **No issues found** (lief diesmal durch);
`flutter test` → **alle 74 Tests grün** (69 alte + 5 neue); `dart format
--output=none --set-exit-if-changed lib test` → 0 Dateien geändert.
Migrationen bis 0030 live auf Prod (`uaaqehspnlncjzrajfue`).
**Uncommittet:** die zwei neuen Testdateien.

**Nicht verifiziert:** der eingeloggte Browser-Klick-Test der zwei Features
(braucht Nutzer-Zugangsdaten, s. Abschnitt 10) und der Archivierungs-
End-to-End-Test (unverändert offen).
