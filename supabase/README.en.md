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
2. Paste the entire contents of [`setup.sql`](setup.sql).
3. **Run**. The script is **idempotent and non-destructive** — it can be run
   any number of times (also on an existing DB) without deleting existing data.

**Option B – Supabase CLI (for versioning):** install the CLI as described in
section 2b, then:
```powershell
supabase login
supabase link --project-ref <YOUR_PROJECT_REF>
supabase db push
```

## 2b. Deploy Edge Functions (for archiving + the admin "danger zone")

The functions under [`functions/`](functions/) run **server-side** (with the
service_role key) and are called by the app:

- `admin-wipe-data`, `admin-factory-reset`, `admin-delete-user` – admin/owner actions
- `archive-proxy` – encrypted yearly archiving to GitHub

They are **not** part of `setup.sql` and must be deployed separately — otherwise
"Wipe data / Factory reset / Archive" fail with *"Failed to fetch"*.

**Where do I type this?** In a **terminal on your PC** – NOT in the Supabase
dashboard and NOT in the app. Step by step (Windows):

1. **Open a terminal:** Start menu → type `PowerShell` → open *Windows
   PowerShell*. (Or in VS Code: menu *Terminal → New Terminal*.)
2. **Change into the project** (where the `supabase/` folder lives):
   ```powershell
   cd "C:\path\to\Money-Manager"
   ```
3. **Install the Supabase CLI** (once) – easiest via [Scoop](https://scoop.sh):
   ```powershell
   scoop install supabase
   ```
   No Scoop? Alternatively download the `supabase_windows_amd64` file from
   <https://github.com/supabase/cli/releases>, unzip it and add the folder to
   your PATH. Verify with `supabase --version`.
   (Note: `npm i -g supabase` is **no longer** supported.)
4. **Log in + link the project** (opens the browser for login):
   ```powershell
   supabase login
   supabase link --project-ref <YOUR_PROJECT_REF>
   ```
   The `--project-ref` is the part of your project URL `https://<REF>.supabase.co`.
5. **Deploy the functions** (run in the project folder from step 2):
   ```powershell
   supabase functions deploy admin-wipe-data     --no-verify-jwt
   supabase functions deploy admin-factory-reset --no-verify-jwt
   supabase functions deploy admin-delete-user   --no-verify-jwt
   supabase functions deploy archive-proxy       --no-verify-jwt
   ```
   Success looks like: *"Deployed Functions on project …"*. Then test again in
   the app.

> **Important – `--no-verify-jwt`:** the functions verify the JWT **and** the
> role themselves in code (`auth.getUser` + `is_admin`/`is_owner`). The gateway
> JWT check must be OFF, otherwise the CORS preflight fails in the **web app**
> (the browser sends `OPTIONS` without a token → 401 → *"Failed to fetch"*).
> The `[functions.*]` entries in [`config.toml`](config.toml) already set this;
> alternatively toggle "Verify JWT" off per function in the dashboard under
> *Edge Functions → … → Details/Settings*.
> `SUPABASE_URL` and `SUPABASE_SERVICE_ROLE_KEY` are provided by Supabase
> automatically.

## 3. Configure auth

- **Authentication → Providers → Email**: leave enabled.
- To get started (small group, quick testing): **Authentication → Sign In /
  Providers → disable "Confirm email"**, so you can log in immediately without
  a confirmation mail. Re-enable for production use.
- You can create users either via **Authentication → Users → Add user** or
  directly in the app via "Register".

## 4. Get the keys

**Project Settings → API**:
- **Project URL** → goes into `SUPABASE_URL`
- **anon / publishable key** → goes into `SUPABASE_ANON_KEY`

> The anon key is meant for client apps and may live in the app — the real
> protection comes from the **RLS policies** (see `setup.sql`).
> NEVER put the **service_role** key into the app.

You then enter these two values into the Flutter app — see the main
[`README.en.md`](../README.en.md), "Setup" section.

## 5. Data model (quick overview)

| Table          | Purpose                                                     |
|----------------|-------------------------------------------------------------|
| `profiles`     | App profile per login (name, `is_admin`/`is_owner`); 1:1 with `auth.users` |
| `accounts`     | Accounts (type, opening balance, currency, net-worth flag)  |
| `categories`   | Income/expense categories (group-wide)                      |
| `transactions` | Transactions (amount in **cents**, type expense/income/transfer) |
| `budgets`, `recurring_rules`, `savings_goals`, `transaction_splits`, `transaction_comments`, `category_rules`, `transaction_templates` | Budgets, recurring rules, savings goals, splits, comments, auto-rules, templates |
| `access_grants`, `account_members` | Per-person grants + shared accounts        |
| `archived_years`, `archive_config` | Yearly archiving (marker/carry-over + repo config) |

**Permissions (RLS):** accounts/transactions (incl. splits, comments,
recurring rules, audit) are visible and editable only for **owners +
grants/members** (since migrations `0018`/`0019`). Categories/budgets/savings
goals remain group-wide. Receipts live per owner (`0026`). Details:
[`setup.sql`](setup.sql).
