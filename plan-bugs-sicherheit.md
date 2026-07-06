# Plan: Bugs & Sicherheit (erstellt 2026-07-05)

Gemeldete Themen: Währungen nicht editierbar/löschbar, Preset-Kategorien bleiben
deutsch, fehlende Nutzer-Trennung (Konten / Papierkorb / Kategorien & Co.),
keine Icon-Auswahl bei eigenen Kategorien, Fragen zu Datensicherheit/
Verschlüsselung und zum öffentlichen GitHub-Repo.

Rechercheergebnis vorab (Code-Stand `main`, 9d646c6):

- RLS für `accounts`/`transactions`/`splits`/`comments`/`recurring` ist im Repo
  **korrekt** auf Besitzer + Freigaben umgestellt (Migrationen 0018–0020, View
  `account_balances` mit `security_invoker = true`). Das beobachtete
  „jeder sieht alle Konten" muss am **Live-Zustand der Prod-DB** liegen
  (alte Policies nicht gedroppt? `access_grants`/`account_members`-Einträge?).
- `categories`, `budgets`, `savings_goals`, `transaction_templates`,
  `category_rules` haben **absichtlich** `using (true)`-Policies
  (0018, Kommentar: „bleiben vorerst gruppenweit — gemeinsame Planung").
  → Kein Bug im engen Sinn, sondern eine zu ändernde Design-Entscheidung.
- Eigene Währungen: `CustomCurrenciesNotifier` hat nur `add()`; UI bietet weder
  Löschen noch Umbenennen. `ExchangeRatesNotifier.removeRate()` existiert,
  ist aber nirgends in der UI verdrahtet. Beides liegt **lokal pro Gerät**
  (SharedPreferences), synct also nicht zwischen Geräten.
- Nachgemeldeter Bug (05.07.): Fremde Währungen erscheinen in der eigenen
  Liste (z. B. „RS" von Fiaz) — Ursache: `allCurrenciesProvider` sammelt die
  Währungen aller **sichtbaren** Konten ein (Freigabe → Konto sichtbar →
  Währung taucht auf). Und: fremde Konten werden **1:1** umgerechnet, weil
  Kurse nur lokal auf dem Gerät des Besitzers liegen (`converterProvider`
  fällt bei unbekanntem Kurs stumm auf 1.0 zurück). Gewünscht: Konten
  anderer mit **deren** Währung/Kursen anzeigen → Kurse müssen in die DB.
- Preset-Kategorien werden per SQL (`_seed_preset_categories()`, deutsche
  Namen) in die DB gesät → Namen sind **Daten**, keine UI-Strings.
- Kategorie anlegen setzt Icon hart auf `'more'`
  (`categories_screen.dart:67`); Icon-Infrastruktur
  (`shared/category_icons.dart`, `iconForToken`) existiert bereits.

---

## Phase 0 — Live-Audit & Bestandsaufnahme — ✅ ERLEDIGT 05.07.2026

**Ergebnisse (alle Punkte durchgeführt, nur lesend):**

1. **🔴 KRITISCH — DB-Wipe ohne Login möglich:** `admin_wipe_data()` und
   `admin_factory_reset()` sind auf Prod als SECURITY DEFINER für **anon +
   authenticated** ausführbar (`proacl` verifiziert: `anon=X`) und haben —
   anders als `purge_year_data`/`set_archive_config`/`clear_archive_config`/
   `admin_list_user_emails` — **keine interne `is_admin()`-Prüfung**. Jeder
   mit dem öffentlichen anon-Key (steht in `connection.json` im public Repo
   und in jedem Web-Bundle) kann per
   `POST /rest/v1/rpc/admin_wipe_data` die komplette DB leeren, ohne Login.
   Ebenso betroffen: `cleanup_old_data(0,0)` (löscht sofort Papierkorb +
   Audit-Log) und `_seed_preset_categories` (harmlos, idempotent).
   **→ Hotfix ist jetzt Schritt 1 von Phase 1.**
2. **Konten-/Papierkorb-„Durchgriff" ist KEIN RLS-Loch:** Policies auf Prod
   entsprechen exakt dem Soll (pg_policies-Dump abgeglichen). In der DB
   existieren 2 Nutzer (Ahmed=Owner, Fiaz) und **zwei gegenseitige
   „view"-Freigaben** (angelegt 04.07. 20:59/21:14) — ihr seht euch, weil
   ihr euch gegenseitig freigegeben habt. Die 4 gelöschten Buchungen liegen
   alle auf Ahmeds „Bargeld"-Konto; Fiaz sieht sie über seine Freigabe.
   `account_members` leer, `owner_id` nirgends NULL.
   Verbleibende echte Probleme: (a) Client-Bug: Konto-Picker im
   Buchungsformular bietet auch nur-ansehbare Fremdkonten an (Speichern
   würde an RLS scheitern); (b) Design-Frage: soll „Ansehen"-Freigabe den
   Papierkorb einschließen?
3. **CRUD-Inventur:** Kategorien haben **gar keine Update-Methode**
   (kein Umbenennen, kein Icon-Wechsel; nur add/delete/setActive/reorder).
   Ebenfalls nicht editierbar (nur anlegen/löschen): Vorlagen,
   Kategorie-Regeln, Kommentare. Eigene Währungen: nur `add()` (bekannt).
   Vollständiges CRUD ok bei: Konten, Buchungen, Daueraufträgen, Budgets
   (setBudget=Upsert), Sparzielen (upsert).
4. **Secret-Scan Git-Historie:** Keine echten Keys/JWTs/Tokens je committet;
   `env.json` nie committet; `windows/certs/` gitignored. Einziger Fund:
   MSIX-Signier-Passwort `MoneyMgr!2026` in alter Version von
   `tool/build-msix.ps1` (Commit 15c70a9, entfernt in d89b27d) — geringe
   Tragweite (nutzlos ohne die nie committete .pfx), aber Zertifikat bei
   Gelegenheit mit neuem Passwort neu erzeugen.
5. **Weitere Advisor-Befunde:** Leaked-Password-Protection (HaveIBeenPwned)
   deaktiviert → in Phase 4 aktivieren. `archive_config` RLS ohne Policies =
   absichtlich (Zugriff nur über definer-RPCs) — ok. Performance-Lints
   (auth_rls_initplan, fehlende FK-Indizes, doppelte permissive Policies,
   ungenutzte Indizes) bei aktueller Datenmenge unkritisch → optionale
   Härtungsmigration in Phase 4.

### Ursprünglicher Audit-Umfang (Referenz)

Ziel: Ursachen belegen statt vermuten; vollständige Inventur.

1. **Prod-DB-Audit** (Supabase MCP, nur SELECT):
   - `pg_policies` für alle Tabellen dumpen und mit `setup.sql`-Sollzustand
     abgleichen (sind die alten `*_all using(true)`-Policies wirklich weg?).
   - Inhalt von `access_grants` und `account_members` prüfen (unbeabsichtigte
     Freigaben zwischen den Nutzern?).
   - `accounts.owner_id` auf NULL-Werte prüfen (Altbestand vor 0018).
   - `get_advisors` (security + performance) laufen lassen.
2. **Reproduktion verstehen:** Mit welchen zwei Konten wurde der
   Konten-/Papierkorb-Durchgriff beobachtet (Original-DB oder Fork-DB)?
   Falls Fork: wurden dort alle Migrationen/`setup.sql` aktuell eingespielt?
3. **CRUD-Inventur aller anlegbaren Objekte** (was kann angelegt, aber nicht
   bearbeitet/gelöscht werden?): Währungen ✗ (belegt), Kategorien (Rename?
   Icon ✗), Tags, Vorlagen, Kategorie-Regeln, Budgets, Sparziele,
   Daueraufträge, Konten, Freigaben.
4. **Secret-Scan der Git-Historie** (service_role-Keys, Tokens, Passwörter;
   `tool/build-msix.ps1` hatte früher ein hart codiertes Passwort → prüfen,
   ob es in der Historie liegt und ob Rotation nötig ist).

Ergebnis: Befundliste mit belegter Ursache pro Symptom.

## Phase 1 — Sicherheits-Hotfix + Nutzer-Trennung (kritisch, zuerst)

1. **🔴 HOTFIX (Migration 0031) — ✅ ERLEDIGT + auf Prod angewendet
   05.07.2026.** `revoke execute` von `anon`/`authenticated`/`public` auf
   `admin_wipe_data`, `admin_factory_reset`, `cleanup_old_data`,
   `_seed_preset_categories` + `get_storage_stats` (nur anon); interner
   Guard `if auth.uid() is not null and not is_admin() then raise` in den
   drei zerstörerischen Funktionen (service_role/pg_cron mit uid NULL bleiben
   erlaubt). Verifiziert: `has_function_privilege` → anon/authenticated
   `false`, service_role `true`; `get_advisors` listet die drei Funktionen
   nicht mehr. `setup.sql` synchron nachgezogen (Neuinstallationen/Forks
   starten geschützt). **Committen steht noch aus** (Konvention: nur auf
   Anweisung).
2. **Konto-Picker-Bug (Client) — ✅ ERLEDIGT 05.07.** Neuer
   `manageableAccountsProvider` (eigene + manage-Freigaben); Buchungsformular,
   Dauerauftrags-Formular und CSV-Import bieten/nutzen nur noch verwaltbare
   Konten (nur-ansehbare Fremdkonten fliegen raus).
   [account_providers.dart](lib/features/accounts/account_providers.dart),
   [transaction_form_screen.dart](lib/features/transactions/transaction_form_screen.dart),
   [recurring_form_screen.dart](lib/features/recurring/recurring_form_screen.dart),
   [csv_import_screen.dart](lib/features/export/csv_import_screen.dart).
3. **Papierkorb-Trennung — ✅ ERLEDIGT 05.07.** `deletedTransactionsProvider`
   zeigt nur noch gelöschte Buchungen aus verwaltbaren Konten (Papierkorb/
   Restore = Verwaltungsaktion; view-Freigabe schließt Papierkorb NICHT ein).
   [transaction_providers.dart](lib/features/transactions/transaction_providers.dart).
4. **Kategorien/Budgets/Sparziele/Vorlagen/Regeln trennen (Migration 0032) —
   ✅ ERLEDIGT + auf Prod angewendet 05.07.2026.** Verifiziert: alle fünf
   Tabellen haben 0 permissive `using(true)`-Policies mehr (nur granulare
   select/insert/update/delete + RESTRICTIVE ro_*); 31 Presets alle
   `owner_id NULL`; `get_advisors` zeigt keine `rls_policy_always_true`-
   Warnungen mehr. categories bekommt `owner_id` (Presets `owner_id NULL` =
   global lesbar; Schreiben nur Admin); budgets/savings_goals/
   transaction_templates/category_rules nutzen die vorhandene Spalte
   `created_by` als Besitzer. Policies **Besitzer + Freigaben**
   (`can_view_owner`/`can_manage_owner`) statt `using (true)`. **Kein
   Backfill nötig** (Prod-Daten: 31 Presets, sonst 0 Zeilen). Category-Modell
   um `ownerId` erweitert.
   [0032_per_owner_planning_data.sql](supabase/migrations/0032_per_owner_planning_data.sql),
   setup.sql-Block angehängt. Verifiziert: `flutter analyze` **No issues**,
   `flutter test` **65/65 grün**, `dart format` clean.
   *Nachgelagert (mit Phase 3 gebündelt):* Picker-Feinschliff „eigene +
   Presets vs. freigegebene Kategorien" (aktuell 0 eigene Kategorien, daher
   keine sichtbare Auswirkung).
5. **Zwei-Nutzer-Verifikation:** vor/zur Prod-Anwendung von 0032 belegen:
   ohne Freigabe nichts Fremdes sichtbar (Konten, Papierkorb, Kategorien,
   Budgets), mit „view"-Freigabe nur Lesbares, Presets für alle. Hinweis:
   Eure gegenseitigen view-Freigaben vom 04.07. bleiben bestehen — ihr seht
   euch weiterhin, bis ihr sie im Sharing-Screen entfernt.

## Phase 2 — Währungen: DB-Umzug, Besitzer-Kurse, bearbeiten & löschen

Entscheidung durch Nachmeldung 05.07. gefallen: Währungen + Kurse müssen in
die **DB pro Besitzer**. **Code ✅ FERTIG 05.07.; ⏳ Prod-Migration 0033
offen (braucht ausdrückliche Freigabe).**

1. **Migration 0033 ✅ geschrieben + setup.sql:** Tabelle `currencies`
   (`owner_id default auth.uid()`, `code`, `rate_to_base numeric null`,
   PK (owner_id, code)); RLS Schreiben nur Besitzer, Lesen `can_view_owner`.
   Zusätzlich `profiles.base_currency` (Default EUR) zur korrekten
   Kurs-Deutung. [0033_currencies_per_owner.sql](supabase/migrations/0033_currencies_per_owner.sql).
2. **Einmal-Import ✅** (`_currencyImportProvider`): schiebt lokale
   `settings_custom_currencies` + `settings_fx_rates` einmalig in die DB und
   spiegelt die Basiswährung ins Profil; Flag `currencies_migrated_v1`.
3. **Konverter besitzerbewusst ✅** (`effectiveRatesProvider`): eigene Kurse
   haben Vorrang; für Codes ohne eigenen Kurs werden die Kurse fremder,
   sichtbarer Besitzer genutzt, sofern deren Basiswährung == meiner. So
   werden freigegebene fremde Konten (z. B. Fiaz' RS) mit dem Kurs des
   Besitzers gerechnet statt 1:1. **Bewusste Vereinfachung:** die vielen
   Aggregate (`converterProvider(cents, code)`) bleiben kontextfrei — pro
   Code EIN wirksamer Kurs, kein per-Konto-Owner-Kontext (der Nutzer kann
   seinen eigenen Kurs für einen Code löschen, damit der Besitzer-Kurs greift).
   Basiswährungs-Kettung bei abweichender Basis bewusst nicht implementiert
   (fremder Kurs wird dann übersprungen → 1:1); aktuell nutzen beide EUR.
4. **Listen-Trennung ✅:** `allCurrenciesProvider` (Picker) = Standard +
   eigene DB-Währungen + Währungen EIGENER Konten; fremde Kontowährungen
   erscheinen NICHT mehr. `usedForeignCurrenciesProvider` = nur eigene Konten.
5. **CRUD ✅:** Kurs setzen/ändern + eigene Währung löschen im
   [exchange_rates_screen.dart](lib/features/currency/exchange_rates_screen.dart)
   (DB-Repo + Invalidation).
6. **Schutz ✅:** von einem eigenen Konto benutzte Währung nicht löschbar
   (Snackbar `currencyInUse`).

Verifiziert: `flutter analyze` **No issues**, `flutter test` **65/65 grün**,
`dart format` clean. **Migration 0033 ✅ auf Prod angewendet + verifiziert
05.07.** (Tabelle currencies + RLS 2 Policies, profiles.base_currency=EUR bei
Ahmed+Fiaz, 0 Kurs-Zeilen → füllen sich beim Einmal-Import). **Offen:**
Phase 2 committen (auf Anweisung).

## Phase 3 — Kategorien: Presets übersetzen, Icons, CRUD-Lücken — ✅ ERLEDIGT 05.07.

Rein clientseitig, KEINE DB-Migration.

1. **Preset-Lokalisierung ✅:** Mapping deutscher Preset-Name → Englisch
   (`_presetCategoryEn` + `presetCategoryName`/`categoryName(Category)`) in
   [app_localizations.dart](lib/l10n/app_localizations.dart). Angewendet nur
   auf `is_preset`. `categoryNamesProvider` ist jetzt locale-/preset-bewusst
   (deckt Buchungslisten, Statistik, Suche, Papierkorb, Export-PDF u.v.m.
   automatisch ab). Picker/Budgets/Regeln direkt auf `l.categoryName(c)`.
   **Wichtig:** CSV-Export nutzt neuen `categoryRawNamesProvider` (rohe
   deutsche Namen) → Round-Trip-Import bleibt intakt.
2. **Icon-Auswahl ✅:** Icon-Picker (Grid aus `categoryIconTokens` in
   [category_icons.dart](lib/shared/category_icons.dart)) im gemeinsamen
   Anlegen-/Bearbeiten-Dialog `showCategoryEditor`; `addCategory` bekommt das
   gewählte Icon statt hart `'more'`.
3. **Bearbeiten/Umbenennen eigener Kategorien ✅:** `updateCategory(id, name,
   icon, kind)` im Repo; Tap auf eine eigene Kategorie öffnet den Editor.
   Presets sind read-only (kein Tap-Edit; RLS erlaubt Schreiben ohnehin nur
   Admin).
4. **Hinweis (Folge aus 0032):** Nicht-Admins können Presets nicht mehr
   umsortieren/aktiv-schalten/löschen (RLS). Der Besitzer (Admin) schon.
   Für das Kleingruppen-Modell akzeptiert; ggf. später verfeinern.

Verifiziert: `flutter analyze` **No issues**, `flutter test` **65/65 grün**,
`dart format` clean. **Offen:** committen (auf Anweisung).

## Phase 4 — Sicherheit, Verschlüsselung, GitHub-Repo

1. **Fragen beantwortet (Doku) — ✅ ERLEDIGT 05.07.** „Datensicherheit &
   Verschlüsselung"-Sektion in [README.md](README.md) + [README.en.md](README.en.md):
   TLS in transit, AES-256 at-rest; anon/Publishable-Key bewusst öffentlich,
   Schutz via RLS + Whitelist; echte Secrets serverseitig; Archiv AES-256-GCM;
   public Repo enthält keine Finanzdaten/Secrets. Berechtigungsmodell-Sektion
   auf den neuen Stand gebracht (Kategorien/Budgets/etc. jetzt pro Besitzer,
   Presets global; Wartungs-RPCs nur Server/Admin).
2. **Härtung — Leaked-Password-Protection:** Advisor meldet sie als AUS.
   Lässt sich NICHT per MCP toggeln → Nutzer aktiviert sie im Supabase-
   Dashboard (Authentication → Policies). In beiden READMEs dokumentiert.
3. **GitHub-Repo / `connection.json` — ENTSCHIEDEN 05.07.: BEHALTEN.**
   Befund: `connection.json` enthält NUR öffentliche Client-Werte (URL +
   `sb_publishable_...`), also KEIN Geheimnis — Entfernen brächte praktisch
   keinen Sicherheitsgewinn, birgt aber Risiko (GitHub-Secrets per `gh` nicht
   verifizierbar → Web könnte ins Onboarding fallen). Nutzer hat nach diesem
   Befund „Behalten" gewählt. Die neue Doku erklärt sauber, warum das sicher
   ist. Git-Historie sonst sauber (nur das alte MSIX-Cert-Passwort in 15c70a9,
   pfx nie committet → Zertifikat bei Gelegenheit neu erzeugen, geringe Prio).
4. Optional (Idee aus handoff): Benachrichtigung bei Neuregistrierung.

## Phase 5 — Verifikation & Abschluss

1. `dart format` + `flutter test` (Basis), `flutter analyze` (sofern er in
   der Umgebung durchläuft), neue Tests für: Währungs-CRUD,
   Preset-Übersetzung, Icon-Roundtrip.
2. Zwei-Nutzer-E2E erneut (wie Phase 1.4) nach allen Migrationen.
3. Doku nachziehen (README Berechtigungsmodell, supabase/README, handoff.md).
4. Commit/Push **nur auf ausdrückliche Anweisung** (Konvention).

---

**Reihenfolge-Begründung:** Phase 1 zuerst, weil Datentrennung das einzige
echte Sicherheitsproblem ist; Phasen 2/3 sind unabhängige UI-Bugs; Phase 4
baut auf den Audit-Ergebnissen aus Phase 0 auf.

**Offene Entscheidungen für den Nutzer (blockieren jeweils nur ihre Phase):**
1. ~~Kategorien/Budgets: strikt privat oder Besitzer + Freigaben?~~
   **Entschieden 05.07.:** Besitzer + Freigaben, gleiche Logik wie Konten.
2. ~~Eigene Währungen: lokal oder DB?~~ **Entschieden 05.07.:** DB pro
   Besitzer (nötig, damit fremde Konten mit den Kursen des Besitzers
   angezeigt werden).
3. ~~`connection.json` behalten oder entfernen?~~ **Zunächst „entfernen"
   (05.07.), nach Befund revidiert → BEHALTEN:** Datei enthält nur öffentliche
   Werte (kein Geheimnis), Entfernen ohne Sicherheitsgewinn + mit Web-Risiko.
   READMEs erklären die Sicherheit stattdessen.
