# Money-Manager · Roadmap

[🇩🇪 Deutsch](ROADMAP.md) · 🇬🇧 **English**

A full-featured **personal-finance app** for a small, trusted group –
one Flutter codebase for **Windows · Android · Web**, backend **Supabase**.

**Architecture decisions:** local-first + delta sync (bandwidth-friendly,
offline) · accounts belong to people, everyone may do everything, views
**separable per person** · categories shared **group-wide** · amounts as
**integer cents**.

Legend: ✅ done · 🔄 in progress · ⬜ open

---

## ✅ Phase 1 — Foundation
Auth, Supabase (Postgres/Auth/Realtime/RLS), first transactions, multi-platform.

## ✅ Phase 2 — Core features (v1)
Categories, edit/delete transaction, attribution, profile.

## ✅ Phase A — Data model v2 (personal finance)
- `accounts` (account types, opening-balance cents, icon/color, credit limit,
  "counts toward net worth", archive) replaces `ledgers`.
- `transactions` with type **expense/income/transfer**, `amount_cents`, title,
  `transfer_account_id`, `deleted_at` tombstones.
- `categories` **group-wide** + an extensive **preset** (migration 0003).
- `account_balances` view; UI: account list per person + **net worth**,
  account detail with balance, transaction form with types/transfer/title/note,
  group-wide category management.

## ✅ Phase B — Local-first (offline cache)
- Persistent offline cache (`shared_preferences`, cross-platform) on top of the
  Supabase realtime stream: **instant and offline-capable start** with the last
  known data, automatic persistence on every update.
- Correctness stays with the proven stream (important for financial data). A pure
  delta sync to further reduce bandwidth is optional/later — not needed for a
  small group (bandwidth isn't the bottleneck).

## ⬜ Phase C — Account polish
- Icon/color picker per account, ordering, person filter in the overview,
  debt/credit overview (liabilities separated), account currency.

## ⬜ Phase D — Transaction convenience
- **Calculator in the amount field** (partial sums), **title autocomplete**
  (+ category suggestion for a known title), correction/balance-reconciliation
  entry, icon/color per category + subcategories.

## ✅ Phase E — Search & statistics
- **Search** across all transactions (title/note/category) + type filter
  (expense/income/transfer) → hits open the transaction directly.
- **Statistics view**: period (month/year/total), totals
  income/expenses/balance, **category breakdown as bars**, net worth + debts.
  All computed locally.
- Open/later: week view + custom period, trend curve, savings rate.

## 🔄 Phase F — More finance features
- ✅ **Budgets** per category (monthly budget, progress + over-budget warning,
  migration 0004).
- ✅ **Recurring transactions** (standing orders): rules per account, interval
  day/week/month/year, start/end date; **race-safe auto-generation** at app
  start (atomic claiming of the period → no double bookings); migration 0005.
- ✅ **CSV export** + **receipts/photos** per transaction (Supabase Storage, compressed).
- ✅ **Admin area + email whitelist**: registration only for allowed emails,
  user overview/management, admin rights, delete user (Edge Function).
- ⬜ Tags, split transactions, PDF export.

## 🔄 Phase G — Quality & release
- ✅ **App icon** (green €, Android/Windows/Web) + app name "Money Manager".
- ✅ **Release builds produced successfully**: Windows (`money_manager.exe`, ~32 MB)
  + Android (`app-release.apk`, ~54 MB). Build fixes: `kotlin.incremental=false`
  (project F: ↔ pub cache C:), Gradle heap 4G/Metaspace 1G (OOM), `compileSdk 36`
  globally for all plugin subprojects. Guide in the README.
- ✅ **Windows MSIX installer** (signed; `tool/build-msix.ps1`).
- ✅ **Calculator keypad** + **menu bar** (tabs) + accounts by category.
- ⬜ Tests (models/repos), CI (GitHub Actions), screenshots.

---

## Frugal with Supabase (free plan)
DB storage is practically never the limit here (transactions = tiny rows). The
real limits are **bandwidth** and the **7-day pause**. Countermeasures:
local-first (load deltas only, statistics locally), integer cents + compact
types, lookup tables, selective realtime, receipts in Storage (not in the DB).
