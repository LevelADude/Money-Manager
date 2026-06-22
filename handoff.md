# Money Manager — Handoff

Stand: 2026-06-22

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

`lib/config/supabase_config.dart` hat **leere Defaults**. Ein frischer
Klon/Fork startet damit leer → Onboarding. Zugangsdaten kommen per
`--dart-define`, **nie** durch Eintragen im Code:

- **Lokal (Windows/Android):** `env.json` (gitignored) via
  `--dart-define-from-file=env.json` — die `tool/run-*.ps1`-Skripte machen das.
- **Web (GitHub Pages):** Repo-Secrets `SUPABASE_URL` + `SUPABASE_ANON_KEY`,
  die der Deploy-Workflow ([.github/workflows/deploy-web.yml](.github/workflows/deploy-web.yml))
  als dart-define übergibt.
- **Pro Gerät zur Laufzeit:** „Datenbank-Verbindung ändern" (Override in
  `AppConfig`), erreichbar aus Profil und Login.

URL + anon/publishable-Key sind ohnehin öffentliche Client-Werte; geschützt
wird über **RLS + E-Mail-Whitelist**. Trotzdem: **`env.json` nicht committen.**

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

- **Finalisierungs-Phase** ist geplant, aber NICHT freigegeben: aufräumen
  (löschen, säubern), Fehler-Check, Verbesserungsvorschläge. Erst auf
  ausdrückliche Anweisung starten.
- Optional verbleibende „generated text"-Buckets übersetzen (Insight-Karten,
  Reminder-/PDF-Texte) — bisher bewusst deutsch.
- `verify`/manuelles Testen auf echtem Android-Gerät (OCR, Beleg-Flow) steht
  noch beim Nutzer aus (hier kein Gerät verfügbar).

---

## Verifikation des aktuellen Stands

`flutter analyze lib` → keine Fehler. `flutter build web --release` →
erfolgreich (die wasm-dry-run-Warnung zu `ua_client_hints`/`dart:html` ist
vorbestehend und betrifft nur potenzielle wasm-Builds, nicht den Standard-Build).
