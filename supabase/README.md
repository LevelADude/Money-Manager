# Supabase-Backend einrichten

🇩🇪 **Deutsch** · [🇬🇧 English](README.en.md)

Das gesamte Backend (Datenbank, Auth, Realtime-Sync) läuft auf Supabase.
Die App braucht nur **Projekt-URL** + **anon (publishable) Key**.

## 1. Projekt anlegen

1. Auf <https://supabase.com> anmelden → **New project**.
2. Name z. B. `money-manager`, Region möglichst nah (z. B. *Central EU (Frankfurt)*).
3. Ein DB-Passwort vergeben (separat speichern, wird selten gebraucht).
4. Warten, bis das Projekt bereit ist (~2 Min).

> Free-Tier-Hinweis: Ein ungenutztes Projekt pausiert nach 7 Tagen Inaktivität
> und lässt sich mit einem Klick reaktivieren. Bei aktiver Nutzung irrelevant.

## 2. Schema einspielen

**Variante A – Dashboard (am einfachsten):**
1. Im Projekt → **SQL Editor** → **New query**.
2. Kompletten Inhalt von [`setup.sql`](setup.sql) einfügen.
3. **Run**. Das Skript ist **idempotent und nicht-destruktiv** — beliebig oft
   ausführbar (auch auf einer bestehenden DB), ohne vorhandene Daten zu löschen.

**Variante B – Supabase CLI (für Versionierung):** CLI installieren wie in
Abschnitt 2b beschrieben, dann:
```powershell
supabase login
supabase link --project-ref <DEINE_PROJECT_REF>
supabase db push
```

## 2b. Edge Functions deployen (für Archiv + Admin-„Gefahrenzone")

Die Funktionen unter [`functions/`](functions/) laufen **serverseitig** (mit dem
service_role-Key) und werden von der App aufgerufen:

- `admin-wipe-data`, `admin-factory-reset`, `admin-delete-user` – Admin-/Besitzer-Aktionen
- `archive-proxy` – verschlüsselte Jahres-Archivierung nach GitHub

Sie sind **nicht** Teil von `setup.sql` und müssen separat deployt werden — sonst
schlagen „Daten leeren / Werkseinstellungen / Archivieren" mit *„Failed to fetch"* fehl.

**Wo gebe ich das ein?** In einem **Terminal auf deinem PC** – NICHT im Supabase-
Dashboard und NICHT in der App. Schritt für Schritt (Windows):

1. **Terminal öffnen:** Start-Menü → `PowerShell` tippen → *Windows PowerShell*
   öffnen. (Oder in VS Code: Menü *Terminal → New Terminal*.)
2. **Ins Projekt wechseln** (dort liegt der `supabase/`-Ordner):
   ```powershell
   cd "C:\Local Data\Programm\Money-Manager"
   ```
3. **Supabase-CLI installieren** (einmalig) – am einfachsten via [Scoop](https://scoop.sh):
   ```powershell
   scoop install supabase
   ```
   Kein Scoop? Alternativ die `supabase_windows_amd64`-Datei von
   <https://github.com/supabase/cli/releases> herunterladen, entpacken und den
   Ordner zum PATH hinzufügen. Prüfen mit `supabase --version`.
   (Hinweis: `npm i -g supabase` wird **nicht** mehr unterstützt.)
4. **Anmelden + Projekt verknüpfen** (öffnet den Browser zum Login):
   ```powershell
   supabase login
   supabase link --project-ref uaaqehspnlncjzrajfue
   ```
   Die `--project-ref` ist der Teil aus deiner Projekt-URL `https://<REF>.supabase.co`.
5. **Funktionen deployen** (im Projektordner aus Schritt 2 ausführen):
   ```powershell
   supabase functions deploy admin-wipe-data     --no-verify-jwt
   supabase functions deploy admin-factory-reset --no-verify-jwt
   supabase functions deploy admin-delete-user   --no-verify-jwt
   supabase functions deploy archive-proxy       --no-verify-jwt
   ```
   Erfolg sieht etwa so aus: *„Deployed Functions on project …"*. Danach in der App
   erneut testen.

> **Wichtig – `--no-verify-jwt`:** Die Funktionen prüfen JWT **und** Rolle selbst
> im Code (`auth.getUser` + `is_admin`/`is_owner`). Die Gateway-JWT-Prüfung muss
> AUS sein, sonst scheitert in der **Web-App** der CORS-Preflight (Browser sendet
> `OPTIONS` ohne Token → 401 → *„Failed to fetch"*). Die `[functions.*]`-Einträge
> in [`config.toml`](config.toml) setzen das bereits; alternativ pro Funktion im
> Dashboard unter *Edge Functions → … → Details/Settings → „Verify JWT"* aus.
> `SUPABASE_URL` und `SUPABASE_SERVICE_ROLE_KEY` stellt Supabase automatisch bereit.

## 3. Auth konfigurieren

- **Authentication → Providers → Email**: aktiviert lassen.
- Für den Start (kleine Gruppe, schnelles Testen): **Authentication → Sign In / Providers → "Confirm email" deaktivieren**, damit man sich ohne Bestätigungsmail sofort einloggen kann. Für den Produktivbetrieb wieder aktivieren.
- Nutzer kannst du entweder per **Authentication → Users → Add user** anlegen oder direkt in der App über „Registrieren".

## 4. Schlüssel holen

**Project Settings → API**:
- **Project URL** → kommt in `SUPABASE_URL`
- **anon / publishable key** → kommt in `SUPABASE_ANON_KEY`

> Der anon-Key ist für Client-Apps gedacht und darf in der App stecken — der
> echte Schutz kommt aus den **RLS-Policies** (siehe `setup.sql`).
> Den **service_role**-Key NIEMALS in die App packen.

Diese beiden Werte trägst du dann in der Flutter-App ein — siehe
Haupt-[`README.md`](../README.md) Abschnitt „Konfiguration".

## 5. Datenmodell (Kurzüberblick)

| Tabelle        | Zweck                                                        |
|----------------|-------------------------------------------------------------|
| `profiles`     | App-Profil pro Login (Name, `is_admin`/`is_owner`); 1:1 zu `auth.users` |
| `accounts`     | Konten (Typ, Anfangssaldo, Währung, Vermögens-Flag)         |
| `categories`   | Einnahme-/Ausgabe-Kategorien (gruppenweit)                  |
| `transactions` | Buchungen (Betrag in **Cent**, Typ expense/income/transfer) |
| `budgets`, `recurring_rules`, `savings_goals`, `transaction_splits`, `transaction_comments`, `category_rules`, `transaction_templates` | Budgets, Daueraufträge, Sparziele, Aufteilungen, Kommentare, Auto-Regeln, Vorlagen |
| `access_grants`, `account_members` | Pro-Person-Freigaben + geteilte Konten        |
| `archived_years`, `archive_config` | Jahres-Archivierung (Marker/Carry-over + Repo-Config) |

**Berechtigungen (RLS):** Konten/Buchungen (inkl. Splits, Kommentare,
Daueraufträge, Audit) sind nur für **Besitzer + Freigaben/Mitglieder** sichtbar
und änderbar (ab Migration `0018`/`0019`). Kategorien/Budgets/Sparziele bleiben
gruppenweit. Belege liegen pro Eigentümer (`0026`). Details: [`setup.sql`](setup.sql).
