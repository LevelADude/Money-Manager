# Architecture

[🇩🇪 Deutsch](ARCHITECTURE.md) · 🇬🇧 **English**

## Overview

```
┌───────────────────────────────┐        ┌──────────────────────────────────┐
│    Flutter app (1 codebase)    │        │             Supabase             │
│  ───────────────────────────   │  HTTPS │  ──────────────────────────────  │
│  Windows · Android · Web (PWA) │◀──────▶│  Postgres + Auth + Realtime      │
│  Riverpod · go_router · DE/EN  │  WSS   │  Storage + Edge Functions + RLS  │
└───────────────────────────────┘        └──────────────────────────────────┘
```

- **One** Dart codebase → native apps for **Windows** and **Android** plus
  **Web/PWA** (GitHub Pages).
- **Supabase** as the backend: Postgres, auth (email/password + whitelist),
  realtime (live sync to all devices), storage (receipt photos), Edge
  Functions (admin maintenance, archive proxy), RLS (permissions in the DB).

## Layers in the app (`lib/`)

```
lib/
├── main.dart                 # Bootstrap: resolve config → Supabase init → app
├── app.dart                  # MaterialApp.router (theme, language, app lock)
├── config/                   # connection resolution (see below)
├── core/
│   ├── router.dart           # go_router incl. auth redirect
│   ├── main_scaffold.dart    # bottom navigation (responsive)
│   └── theme.dart            # light/dark + accent colors
├── data/
│   ├── models/               # plain Dart models (Account, AppTransaction,
│   │                         #   Budget, Category, RecurringRule, …)
│   ├── repositories/         # Supabase access, ONE repo class per domain
│   └── local/app_cache.dart  # offline cache (local-first, SharedPreferences)
├── features/                 # one folder per feature: *_screen.dart (UI)
│   │                         #   + *_providers.dart (Riverpod)
│   └── accounts · transactions (+ocr) · statistics · budgets · savings ·
│       categories · recurring · planning · projects · debts · settle ·
│       sharing · currency · export · backup · insights · reminders ·
│       activity · search · archive · admin · profile · auth · onboarding ·
│       settings · simulator · more
├── shared/                   # reusable widgets/helpers
│                             #   (MoneyText, calculator, charts, …)
└── l10n/app_localizations.dart  # central DE/EN translation table
```

### Responsibilities

| Layer          | Job                                                           |
|----------------|--------------------------------------------------------------|
| **models**     | Type-safe mapping of DB rows, JSON conversion                |
| **repositories** | The only place that talks to the Supabase client           |
| **providers**  | Riverpod: holds state, connects UI ↔ repository, streams     |
| **screens/widgets** | pure rendering + user interaction                       |

## Connection resolution (self-hosting)

The app finds its Supabase connection in this order (highest first):

1. **Per-device override** – "Change database connection" (login/profile) or
   onboarding; stored in SharedPreferences.
2. **Committed `assets/db_connection/connection.json`** – permanently binds an
   instance/fork to its DB (works on all platforms). In the upstream this is
   deliberately just a **placeholder** (`DEIN-PROJEKT…`, ignored) so a fresh
   fork starts empty instead of binding to the foreign DB.
3. **dart-define** – locally `env.json`, in the web deploy GitHub secrets.
4. Nothing set → **onboarding** (create a new DB or connect to an existing one).

## State management: Riverpod (3.x)

- Repositories deliver **cache-then-stream**: on startup the last known data
  from the offline cache immediately, then the realtime stream (local-first).
- One provider set per feature; derived values (balances, statistics,
  insights) are computed **locally** from the streamed transactions.
- A transaction recorded on the PC appears on the phone immediately – no
  manual refresh.

## Routing: go_router

- Not logged in → `/login`; a `redirect` watches the auth state.
- Logged in → bottom navigation (Accounts · Transactions · Statistics · More)
  with subroutes per feature (e.g. `/more/archive`).
- Onboarding runs **before** Riverpod initialization as its own MaterialApp.

## Permission model

Access only via the **email whitelist**; the first registered person becomes
the **owner**. Accounts + transactions are restricted via RLS to **owner +
grants/joint accounts**; categories/budgets/savings goals are deliberately
group-wide; receipts live per owner. Destructive admin actions and the yearly
archiving run through **Edge Functions** (secrets stay server-side). All
defined in [`supabase/setup.sql`](../supabase/setup.sql).

## Why this stack?

- **Flutter**: one codebase for Windows, Android **and** Web, real native
  builds, a mature official Supabase SDK.
- **Supabase**: Postgres (ideal for financial data: sums, integrity,
  transactions), a free tier, auth + realtime + storage built in, RLS for
  permissions directly in the DB instead of error-prone in the app.
- **Amounts as integer cents**, money format `de_DE` – no float rounding
  errors.
- **Privacy**: insights/OCR run 100 % locally on the device – deliberately no
  cloud LLM.
