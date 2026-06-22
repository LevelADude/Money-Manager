# Set up the Supabase backend

[🇩🇪 Deutsch](README.md) · 🇬🇧 **English**

The entire backend (database, auth, realtime sync) runs on Supabase.
The app only needs the **Project URL** + **anon (publishable) key**.

## 1. Create a project

1. Sign in at <https://supabase.com> → **New project**.
2. Name e.g. `money-manager`, region as close as possible (e.g. *Central EU (Frankfurt)*).
3. Set a DB password (store it separately, rarely needed).
4. Wait until the project is ready (~2 min).

> Free-tier note: an unused project pauses after 7 days of inactivity and can be
> reactivated with one click. Irrelevant with active use.

## 2. Apply the schema

**Option A – Dashboard (easiest):**
1. In the project → **SQL Editor** → **New query**.
2. Paste the entire contents of [`migrations/0001_init.sql`](migrations/0001_init.sql).
3. **Run**. The script is idempotent — running it again does no harm.

**Option B – Supabase CLI (for later/versioning):**
```bash
npm i -g supabase
supabase login
supabase link --project-ref <YOUR_PROJECT_REF>
supabase db push
```

## 3. Configure auth

- **Authentication → Providers → Email**: leave enabled.
- To get started (small group, quick testing): **Authentication → Sign In / Providers → disable "Confirm email"**, so you can log in immediately without a confirmation mail. Re-enable for production use.
- You can create users either via **Authentication → Users → Add user** or directly in the app via "Register".

## 4. Get the keys

**Project Settings → API**:
- **Project URL** → goes into `SUPABASE_URL`
- **anon / publishable key** → goes into `SUPABASE_ANON_KEY`

> The anon key is meant for client apps and may live in the app — the real
> protection comes from the **RLS policies** (see `0001_init.sql`).
> NEVER put the **service_role** key into the app.

You then enter these two values into the Flutter app — see the
main [`README.en.md`](../README.en.md), "Setup" section.

## 5. Data model (quick overview)

| Table          | Purpose                                                     |
|----------------|-------------------------------------------------------------|
| `profiles`     | App profile per login (name); 1:1 with `auth.users`         |
| `ledgers`      | The separate books, one `owner_id` per person               |
| `categories`   | Income/expense categories per book                          |
| `transactions` | Individual entries (date, amount, direction, note)          |
| `ledger_balances` | View: balance + transaction count per book               |

**Permissions (RLS):** every signed-in member may read *and* edit **all** books
and transactions. Whoever created something is recorded in `owner_id` or
`created_by`. To make it stricter = only change the policies in `0001_init.sql`.
