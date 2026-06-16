# Supabase-Backend einrichten

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
2. Inhalt von [`migrations/0001_init.sql`](migrations/0001_init.sql) komplett einfügen.
3. **Run**. Das Skript ist idempotent — erneutes Ausführen schadet nicht.

**Variante B – Supabase CLI (für später/Versionierung):**
```bash
npm i -g supabase
supabase login
supabase link --project-ref <DEINE_PROJECT_REF>
supabase db push
```

## 3. Auth konfigurieren

- **Authentication → Providers → Email**: aktiviert lassen.
- Für den Start (kleine Gruppe, schnelles Testen): **Authentication → Sign In / Providers → "Confirm email" deaktivieren**, damit man sich ohne Bestätigungsmail sofort einloggen kann. Für den Produktivbetrieb wieder aktivieren.
- Nutzer kannst du entweder per **Authentication → Users → Add user** anlegen oder direkt in der App über „Registrieren".

## 4. Schlüssel holen

**Project Settings → API**:
- **Project URL** → kommt in `SUPABASE_URL`
- **anon / publishable key** → kommt in `SUPABASE_ANON_KEY`

> Der anon-Key ist für Client-Apps gedacht und darf in der App stecken — der
> echte Schutz kommt aus den **RLS-Policies** (siehe `0001_init.sql`).
> Den **service_role**-Key NIEMALS in die App packen.

Diese beiden Werte trägst du dann in der Flutter-App ein — siehe
Haupt-[`README.md`](../README.md) Abschnitt „Konfiguration".

## 5. Datenmodell (Kurzüberblick)

| Tabelle        | Zweck                                                        |
|----------------|-------------------------------------------------------------|
| `profiles`     | App-Profil pro Login (Name); 1:1 zu `auth.users`            |
| `ledgers`      | Die getrennten Bücher, je `owner_id` einer Person           |
| `categories`   | Einnahme-/Ausgabe-Kategorien je Buch                        |
| `transactions` | Einzelne Buchungen (Datum, Betrag, Richtung, Notiz)         |
| `ledger_balances` | View: Saldo + Buchungsanzahl je Buch                     |

**Berechtigungen (RLS):** Jedes angemeldete Mitglied darf **alle** Bücher und
Buchungen lesen *und* bearbeiten. Wer etwas angelegt hat, steht in `owner_id`
bzw. `created_by`. Strenger machen = nur die Policies in `0001_init.sql` ändern.
