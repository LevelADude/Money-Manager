# Architektur

## Überblick

```
┌───────────────────────────┐        ┌──────────────────────────────┐
│   Flutter-App (1 Codebase) │        │           Supabase           │
│  ───────────────────────   │  HTTPS │  ──────────────────────────  │
│  Windows-Desktop  ⟷  Android│◀──────▶│  Postgres + Auth + Realtime  │
│  Riverpod · go_router      │  WSS   │  Row Level Security (RLS)    │
└───────────────────────────┘        └──────────────────────────────┘
```

- **Eine** Dart-Codebasis → native Apps für **Windows** und **Android**.
- **Supabase** als Backend: Postgres-Datenbank, Auth (E-Mail/Passwort),
  Realtime (Live-Sync auf alle Geräte), RLS (Berechtigungen in der DB).

## Schichten in der App (`lib/`)

```
lib/
├── main.dart                 # Einstieg: Supabase init + ProviderScope
├── app.dart                  # MaterialApp.router, Theme
├── config/
│   └── supabase_config.dart  # URL/anon-Key aus --dart-define-from-file
├── core/
│   ├── router.dart           # go_router inkl. Auth-Redirect
│   └── theme.dart            # App-Theme (hell/dunkel)
├── data/
│   ├── models/               # Plain-Dart-Modelle (fromJson/toJson)
│   │   ├── profile.dart
│   │   ├── ledger.dart
│   │   └── app_transaction.dart
│   └── repositories/         # Supabase-Zugriff (CRUD + Realtime-Streams)
│       ├── auth_repository.dart
│       ├── ledger_repository.dart
│       └── transaction_repository.dart
└── features/                 # UI je Feature + Riverpod-Provider
    ├── auth/
    ├── ledgers/
    └── transactions/
```

### Verantwortlichkeiten

| Schicht        | Aufgabe                                                        |
|----------------|---------------------------------------------------------------|
| **models**     | Typsichere Abbildung der DB-Zeilen, JSON-Konvertierung        |
| **repositories** | Einziger Ort, der mit dem Supabase-Client spricht           |
| **providers**  | Riverpod: hält Zustand, verbindet UI ↔ Repository, Streams    |
| **screens/widgets** | reine Darstellung + Nutzerinteraktion                    |

## State-Management: Riverpod

- `authStateProvider` – Stream der Supabase-Auth-Session → steuert Routing.
- `ledgersProvider` – Realtime-Stream aller Bücher.
- `transactionsProvider(ledgerId)` – Realtime-Stream der Buchungen eines Buchs.

Realtime sorgt dafür, dass eine Buchung, die auf dem PC erfasst wird, auf dem
Handy sofort erscheint – ohne manuelles Aktualisieren.

## Routing: go_router

- Nicht eingeloggt → `/login`.
- Eingeloggt → `/` (Bücher-Liste) → `/ledger/:id` (Buchungen) → `/ledger/:id/new` (Buchung erfassen).
- Ein `redirect` beobachtet den Auth-Zustand und leitet automatisch um.

## Berechtigungsmodell

Bewusst einfach für eine kleine, vertrauenswürdige Gruppe:
**jedes angemeldete Mitglied darf alles lesen und bearbeiten.** Die Trennung der
Buchhaltungen ist organisatorisch (eigene `ledgers` pro Person), nicht
zugriffsbeschränkt. Umgesetzt über RLS-Policies in
[`supabase/migrations/0001_init.sql`](../supabase/migrations/0001_init.sql).
Verschärfen = nur die Policies ändern, App bleibt unverändert.

## Warum dieser Stack?

- **Flutter**: eine Codebasis für Windows **und** Android, echte native Builds,
  ausgereiftes offizielles Supabase-SDK.
- **Supabase**: Postgres (ideal für Finanzdaten: Summen, Integrität,
  Transaktionen), kostenloser Tier, Auth + Realtime eingebaut, RLS für
  Berechtigungen direkt in der DB statt fehleranfällig in der App.
