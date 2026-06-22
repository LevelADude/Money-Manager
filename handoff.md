# Money Manager — Handoff

Stand: 2026-06-22

> **Zuletzt erledigt (diese Session):** **Archivierung alter Jahre nach GitHub
> — Code-Seite vollständig implementiert & verifiziert** (analyze sauber, 49
> Tests grün, Web-Build ohne ML-Kit). Das Archiv-Repo ist **pro Instanz IN DER
> APP einrichtbar** (Repo+Token; Token/Schlüssel serverseitig in Supabase, nicht
> als Function-Secret). Offen ist nur das **Deployment** (privates Repo,
> Token, Migrationen 0024+0025 anwenden, Edge Function deployen, in der App
> verbinden) — Checkliste in **Abschnitt 11** (11.0). Noch **nicht
> committet/gepusht.**
> **Davor:** DB fest über committete `assets/db_connection/connection.json`
> gebunden (Abschnitt 5).

Gemeinsame Finanz-Buchhaltung für eine kleine Gruppe (Windows + Android, dazu
Web), Daten-Sync über **Supabase**. Flutter-App, zweisprachig **DE/EN**.

Dieses Dokument ist der Einstieg für eine neue Person (oder eine neue
Session). Tieferes liegt in [README.md](README.md), [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md),
[docs/ROADMAP_AUSBAU.md](docs/ROADMAP_AUSBAU.md) und [supabase/README.md](supabase/README.md).

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

- **Migrationen:** `supabase/migrations/0001…0023_*.sql`. `supabase/setup.sql`
  ist das **Komplett-Setup** (alle Tabellen + RLS + Storage), das im Onboarding
  zum Kopieren angeboten wird (als Asset gebündelt).
- **Edge Functions** (`supabase/functions/`, Deno):
  `admin-delete-user`, `admin-wipe-data`, `admin-factory-reset`.
- **Rollen:** erste registrierte E-Mail wird **Besitzer** (`is_owner`,
  Migration 0022); Admin-Wartung in 0023. Zugriff zusätzlich über
  E-Mail-Whitelist (0007) + RLS gesteuert.
- **Produktiv-Projekt:** Supabase `uaaqehspnlncjzrajfue` (Migrationen 0001–0023
  dort angewandt).

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

**Bewusst deutsch geblieben (Daten/Format, keine UI-Chrome):**
- CSV-Export/-Import-Format (Spalten `Datum;Typ;Betrag;…`) — für Round-Trip-Import.
- `period_filter.dart` Extension-Labels (`.label`/`labelFor`) — **ungenutzt**
  (Statistik hat eigene lokalisierte Helfer).
- Ein Provider-Fallback `'Unbekannt'` in `person_filter.dart` (kein `context`).
- Insight-Kartentexte ([insights_providers.dart](lib/features/insights/insights_providers.dart)),
  Reminder-/PDF-Texte.
- Geldformat bleibt `de_DE`; numerische Datumsangaben bleiben `dd.MM.yyyy`.

---

## 7. Nennenswerte Features

- Konten (mehrere Typen, Archiv, Sortierung, Gemeinschaftskonten/Freigaben).
- Buchungen: Einnahme/Ausgabe/Übertrag, Splits, Vorlagen, Tags, Beleg-Foto
  (**Kompression vor Upload**, [shared/image_compress.dart](lib/shared/image_compress.dart)),
  Papierkorb (30 Tage, Retention-Cleanup-Migration 0021).
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

---

## 10. Offene Punkte / als Nächstes

- ⭐ **NÄCHSTE AUFGABE: Archivierung alter Jahre nach GitHub** — vom Nutzer
  angefordert, **noch nicht begonnen**. Vollständige Anforderung + technischer
  Plan + offene Entscheidungen in **Abschnitt 11**. Vor der Implementierung die
  dort markierten ⚠️-Entscheidungen mit dem Nutzer klären (v. a. Repo-Sichtbarkeit
  und Kontosalden).
- **Finalisierungs-Phase** ist geplant, aber NICHT freigegeben: aufräumen
  (löschen, säubern), Fehler-Check, Verbesserungsvorschläge. Erst auf
  ausdrückliche Anweisung starten.
- Optional verbleibende „generated text"-Buckets übersetzen (Insight-Karten,
  Reminder-/PDF-Texte) — bisher bewusst deutsch.
- `verify`/manuelles Testen auf echtem Android-Gerät (OCR, Beleg-Flow) steht
  noch beim Nutzer aus (hier kein Gerät verfügbar).

---

## 11. Archivierung alter Jahre nach GitHub — IMPLEMENTIERT (Deploy offen)

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

**Noch zu tun (Deployment — braucht den Nutzer):**
1. Privates Repo anlegen (leer, nur Daten).
2. Fine-grained PAT (nur dieses Repo, „Contents: Read and write").
3. Migrationen **0024 + 0025** auf Prod-Supabase `uaaqehspnlncjzrajfue` anwenden.
4. `supabase functions deploy archive-proxy` (oder via Dashboard) — **keine
   Function-Secrets nötig.**
5. **In der App** „Archiv-Repo verbinden" (Repo + Token; Schlüssel wird erzeugt
   und einmalig angezeigt → **sichern**).
6. End-to-End mit Owner-Konto testen (archivieren → ansehen → de-archivieren).

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

**DB-Bindung (diese Session):** `flutter analyze lib/main.dart
lib/config/app_config.dart lib/config/db_connection_file.dart` → keine Fehler;
`flutter test` → alle 49 Tests grün. Asset `assets/db_connection/` in
[pubspec.yaml](pubspec.yaml) registriert. **Noch offen:** committen + pushen, damit
der Web-Deploy die Datei einbäckt (siehe Self-Hosting, Abschnitt 5).

Älterer Stand: `flutter analyze lib` → keine Fehler. `flutter build web --release`
→ erfolgreich (die wasm-dry-run-Warnung zu `ua_client_hints`/`dart:html` ist
vorbestehend und betrifft nur potenzielle wasm-Builds, nicht den Standard-Build).
