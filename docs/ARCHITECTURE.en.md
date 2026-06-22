# Architecture

[🇩🇪 Deutsch](ARCHITECTURE.md) · 🇬🇧 **English**

## Overview

```
┌───────────────────────────┐        ┌──────────────────────────────┐
│   Flutter app (1 codebase) │        │           Supabase           │
│  ───────────────────────   │  HTTPS │  ──────────────────────────  │
│  Windows desktop  ⟷  Android│◀──────▶│  Postgres + Auth + Realtime  │
│  Riverpod · go_router      │  WSS   │  Row Level Security (RLS)    │
└───────────────────────────┘        └──────────────────────────────┘
```

- **One** Dart codebase → native apps for **Windows** and **Android**.
- **Supabase** as the backend: Postgres database, auth (email/password),
  realtime (live sync to all devices), RLS (permissions in the DB).

## Layers in the app (`lib/`)

```
lib/
├── main.dart                 # Entry: Supabase init + ProviderScope
├── app.dart                  # MaterialApp.router, theme
├── config/
│   └── supabase_config.dart  # URL/anon key from --dart-define-from-file
├── core/
│   ├── router.dart           # go_router incl. auth redirect
│   └── theme.dart            # app theme (light/dark)
├── data/
│   ├── models/               # plain Dart models (fromJson/toJson)
│   │   ├── profile.dart
│   │   ├── ledger.dart
│   │   └── app_transaction.dart
│   └── repositories/         # Supabase access (CRUD + realtime streams)
│       ├── auth_repository.dart
│       ├── ledger_repository.dart
│       └── transaction_repository.dart
└── features/                 # UI per feature + Riverpod providers
    ├── auth/
    ├── ledgers/
    └── transactions/
```

### Responsibilities

| Layer          | Job                                                           |
|----------------|--------------------------------------------------------------|
| **models**     | Type-safe mapping of DB rows, JSON conversion                |
| **repositories** | The only place that talks to the Supabase client           |
| **providers**  | Riverpod: holds state, connects UI ↔ repository, streams     |
| **screens/widgets** | pure rendering + user interaction                       |

## State management: Riverpod

- `authStateProvider` – stream of the Supabase auth session → drives routing.
- `ledgersProvider` – realtime stream of all books.
- `transactionsProvider(ledgerId)` – realtime stream of a book's transactions.

Realtime ensures that a transaction recorded on the PC appears on the phone
immediately – without a manual refresh.

## Routing: go_router

- Not logged in → `/login`.
- Logged in → `/` (book list) → `/ledger/:id` (transactions) → `/ledger/:id/new` (record transaction).
- A `redirect` watches the auth state and reroutes automatically.

## Permission model

Deliberately simple for a small, trusted group:
**every signed-in member may read and edit everything.** Separation of the books
is organizational (each person's own `ledgers`), not access-restricted.
Implemented via RLS policies in
[`supabase/migrations/0001_init.sql`](../supabase/migrations/0001_init.sql).
To tighten = only change the policies, the app stays unchanged.

## Why this stack?

- **Flutter**: one codebase for Windows **and** Android, real native builds,
  a mature official Supabase SDK.
- **Supabase**: Postgres (ideal for financial data: sums, integrity,
  transactions), a free tier, auth + realtime built in, RLS for permissions
  directly in the DB instead of error-prone in the app.
