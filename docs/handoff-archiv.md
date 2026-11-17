# Money Manager — Handoff-Archiv

Sitzungsprotokolle bis 2026-07-03, am 2026-11-15 aus `handoff.md` ausgelagert. Aktueller Stand: Vault-Projekt-Notiz.

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
