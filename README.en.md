# Money-Manager

[🇩🇪 Deutsch](README.md) · 🇬🇧 **English**

Shared **finance bookkeeping for a small, trusted group** – one Flutter
codebase for **Windows**, **Android** and **Web (PWA)**, bilingual
**German/English**. Each person manages their own accounts; sharing happens
deliberately via grants and joint accounts. All devices sync live via
**Supabase**.

## Tech stack

| Area           | Choice                                                   |
|----------------|----------------------------------------------------------|
| UI / client    | **Flutter** (Windows + Android + Web, one codebase)      |
| Backend        | **Supabase** (Postgres, Auth, Realtime, Storage, Edge Functions) |
| Permissions    | **Row Level Security** in the database                   |
| State mgmt     | **Riverpod**                                             |
| Navigation     | **go_router**                                            |

Why this stack? → [`docs/ARCHITECTURE.en.md`](docs/ARCHITECTURE.en.md)

## Screenshots


| Accounts | Transactions | Statistics |
|---|---|---|
| ![Accounts](docs/screenshots/01-konten.png) | ![Transactions](docs/screenshots/02-buchungen.png) | ![Statistics](docs/screenshots/04-statistik.png) |

| New transaction | Onboarding | Desktop (Windows) |
|---|---|---|
| ![New transaction](docs/screenshots/03-buchung-neu.png) | ![Onboarding](docs/screenshots/05-onboarding.png) | ![Desktop](docs/screenshots/06-desktop.png) |

## 🚀 Your own instance (no programming skills needed)

Want to run the app with **your own free database** – on phone, tablet, laptop or
desktop – without writing or building anything? Here's how, in a few minutes:

1. **Fork the repo.** Click **"Fork"** at the top right → the project is now in
   your GitHub account.
2. **No "decoupling" step needed.** The bundled
   `assets/db_connection/connection.json` is only a **placeholder** — a fresh
   fork does **not** connect to a foreign database with it; it starts **empty**
   in the onboarding. So you do **not** need to delete the file. You bind
   **your own** database in step 5 (secrets, recommended) or directly in the
   onboarding (step 6). *(Advanced: instead of secrets you can also replace the
   placeholder values with your own project's credentials — then your site
   binds to it permanently.)*
3. **Create a free Supabase project.** Sign up at
   [supabase.com](https://supabase.com) → **New Project** (Europe region
   recommended) → wait a moment until it's ready.
4. **Set up the database (1 click).** In the Supabase dashboard open the
   **"SQL Editor"**, paste the entire contents of
   [`supabase/setup.sql`](supabase/setup.sql) and click **"Run"**. (The app also
   offers this SQL text via a copy button on first launch.)
   - Optional, so registration works without email confirmation:
     **Authentication → Providers → Email → turn off "Confirm email".**
5. **Publish the website (GitHub Pages).** In your fork:
   **Settings → Pages → Source: "GitHub Actions".** Then under **Actions** run
   the **"Deploy Web (GitHub Pages)"** workflow once (or make a small commit).
   After ~2 minutes the site is reachable at
   `https://<your-name>.github.io/<repo-name>/`.
   - **Optional (auto-connect your site):** In **Settings → Secrets and variables
     → Actions** store the two secrets `SUPABASE_URL` and `SUPABASE_ANON_KEY`
     (of **your own** project from step 3). Then *your* published site connects
     to your database automatically. Without the secrets the site starts empty
     and asks for the credentials in the onboarding (see step 6).
6. **Open the app & connect.** A fresh fork (with the placeholder
   `connection.json`, see step 2) starts **empty** and shows the onboarding
   with two paths:
   **"New installation"** (your own empty DB) or **"Connect to an existing
   DB"**. Enter the **Supabase URL** and **anon/publishable key** (both in
   the Supabase dashboard under *Project Settings → Data API* and *API
   Keys*) → **"Connect & start"**.
   - **The first person to register automatically becomes the owner**
     (administrator with all rights – protected, cannot be removed).
   - Change/disconnect later: **More → Settings → Database connection**
     (this device only, your data is kept).

> **Does your `connection.json` contain real, foreign credentials?** (Only on
> very old forks, or if entered by hand — the bundled file is a placeholder
> today.) Then your site connects to that foreign database. Tell-tale sign:
> unexpected accounts show up in the affected project's Supabase dashboard
> (Authentication → Users). Fix: reset the file to the placeholder (or
> overwrite it with **your own** project's credentials), redeploy, and remove
> the accidentally created accounts there.

> **On iPhone:** open the site in **Safari** → **Share** → **"Add to Home
> Screen"**. Money Manager then launches like a real app (PWA). On Android the
> same works in Chrome ("Install app").

### 🔄 Getting updates automatically

Your fork gets bugfixes and new features from this original repo **automatically**
— **once a week** (Mondays) a bundled workflow ("Sync Fork with Upstream")
syncs your fork with the original. Your own database connection
(`assets/db_connection/connection.json`) is **guaranteed to stay untouched**.
After a clean sync, your site redeploys automatically (via "Deploy Web").

- **Update immediately instead of waiting a week:** in your fork, go to
  **Actions → "Sync Fork with Upstream" → Run workflow**.
- **If you've made your own code changes in the fork** and that causes a real
  conflict (not with `connection.json` — that's protected): the workflow
  won't merge silently, it opens a **pull request** for manual review under
  **Pull requests** instead.
- No setup needed — the workflow is part of this repo and comes with every
  new fork automatically.

> **Hosting alternative:** instead of GitHub Pages you can upload the `build/web`
> folder (after `flutter build web`) to **Cloudflare Pages** or **Netlify** –
> both free and without a third-party account. GitHub Pages is preconfigured here
> and the easiest.

The credentials stay **only locally on the device** (or browser) – not in the
code and not on GitHub. Each person/instance thus uses their **own separate
database**.

---

## 🗄️ Archive old years (optional – free up storage)

When the free Supabase storage gets tight (mainly due to receipt photos), you can
**export old years, encrypted, to a private GitHub repo**. They remain
**viewable but read-only** in the app and no longer count toward
statistics/budgets. Each instance configures its **own** archive repo.

> ⚠️ Only use this when storage is nearly full. Archived years can only be edited
> again after restoring them.

**How to set it up:**

1. **Create a private archive repo.** On GitHub create a **new, private** repo
   (e.g. `money-manager-archive`) – **empty, no code**; it only holds the archive
   files (`archive/<year>.json.enc`). Private matters: your financial data lives
   there (additionally encrypted).
2. **Create an access token.** GitHub → **Settings → Developer settings →
   Personal access tokens → Fine-grained tokens → Generate new token**:
   - **Repository access:** "Only select repositories" → your archive repo.
   - **Permissions → Repository permissions → Contents: Read and write.**
   - Generate and **copy** the token (shown only once).
3. **Apply the database functions.** For a **new** instance everything is already
   in [`supabase/setup.sql`](supabase/setup.sql). For an **existing** instance,
   additionally run
   [`supabase/migrations/0024_archived_years.sql`](supabase/migrations/0024_archived_years.sql)
   and [`supabase/migrations/0025_archive_config.sql`](supabase/migrations/0025_archive_config.sql)
   in the Supabase **SQL Editor**.
4. **Deploy the Edge Function.** The function
   [`supabase/functions/archive-proxy`](supabase/functions/archive-proxy) keeps
   token & key server-side (never in the client). Deploy via CLI
   `supabase functions deploy archive-proxy` **or** in the Supabase dashboard
   under **Edge Functions → Deploy a new function** (paste the code from
   `index.ts`). **No** function secrets are needed – repo/token/key come from the
   app (step 5).
5. **Connect in the app.** **More → Archived years** (or
   **Administration → Archive old years**) → **"Connect archive repo"**: enter
   repo (`owner/name` or URL) and token → **Connect**. The app generates an
   **encryption key** and shows it **once** – **save a copy** (without it,
   archives cannot be recovered if the database is lost). Token & key are then
   stored server-side in Supabase.
6. **Archive.** Check the years → confirm the warning → done. Use **"View"** to
   read a year read-only; **"Restore"** (admin) brings it back into the DB.

---

## Prerequisites (one-time setup)

1. **Flutter SDK** – installed to `C:\dev\flutter` in this project. So `flutter`
   works everywhere, add `C:\dev\flutter\bin` to the **PATH** environment
   variable (Windows search → "Edit environment variables").
2. **For Android builds:** Android Studio (includes Android SDK + emulator).
   Then run `flutter doctor --android-licenses` once.
3. **For Windows desktop builds:**
   - **Visual Studio** (Community is enough) with the workload
     *"Desktop development with C++"*.
   - **Enable Windows developer mode** (for plugin symlinks):
     Settings → *For developers* → **Developer Mode: On**
     (or `start ms-settings:developers`).
4. Check status with:
   ```powershell
   flutter doctor
   ```

## Setup

### 1. Supabase backend
Follow [`supabase/README.en.md`](supabase/README.en.md): create a project, apply
the schema from [`supabase/setup.sql`](supabase/setup.sql) (one script,
idempotent), copy the **Project URL** + **anon/publishable key**.

### 2. Store credentials locally
```powershell
Copy-Item env.example.json env.json
```
Then open `env.json` and enter your values:
```json
{
  "SUPABASE_URL": "https://your-project.supabase.co",
  "SUPABASE_ANON_KEY": "your-anon-publishable-key"
}
```
`env.json` is in `.gitignore` and is **not** committed.

### 3. Fetch dependencies
```powershell
flutter pub get
```

## Run

```powershell
# Windows desktop
flutter run -d windows --dart-define-from-file=env.json
#   or via script:
.\tool\run-windows.ps1

# Android (device/emulator must appear in `flutter devices`)
flutter run -d android --dart-define-from-file=env.json
#   or via script:
.\tool\run-android.ps1
```

> Note: `env.json` is the most convenient way for your **own developer instance**
> (credentials baked in). If you omit it, the app shows the **onboarding** on
> first launch and asks for URL + key there (see
> [Your own instance](#-your-own-instance-no-programming-skills-needed)).
> Connection resolution order (highest first): **1.** per-device connection
> ("Change database connection"/onboarding) → **2.** committed
> `assets/db_connection/connection.json` → **3.** `env.json` or GitHub secrets.

## Project structure

```
Money-Manager/
├── lib/
│   ├── main.dart                 # Bootstrap: check config, Supabase init, app start
│   ├── app.dart                  # MaterialApp.router (theme, language, app lock)
│   ├── config/                   # Connection resolution (device override, connection.json, dart-define)
│   ├── core/                     # Router + bottom navigation + theme
│   ├── data/
│   │   ├── models/               # Account, AppTransaction, Budget, Category, …
│   │   ├── repositories/         # Supabase access (one repo class per domain)
│   │   └── local/                # Offline cache (local-first)
│   ├── features/                 # per feature: screen + Riverpod providers
│   │   └── accounts / transactions / statistics / budgets / savings /
│   │       recurring / planning / debts / projects / settle / insights /
│   │       reminders / archive / export / backup / admin / settings / …
│   ├── shared/                   # reusable widgets/helpers
│   └── l10n/                     # DE/EN translation table (hand-maintained)
├── supabase/
│   ├── setup.sql                 # Complete setup (idempotent) for new instances
│   ├── migrations/               # Schema history 0001…
│   ├── functions/                # Edge Functions (admin maintenance, archive proxy)
│   └── README.md                 # Backend setup
├── docs/ARCHITECTURE.md
├── tool/                         # run/build scripts (Windows/Android/MSIX)
├── env.example.json              # template for env.json
└── ...                           # android/ · windows/ · web/ (generated by Flutter)
```

## Permission model

Built for a **small, trusted group** – but with clear boundaries (enforced via
RLS in the database):

- **Access** only for people unlocked via the **email whitelist**; the first
  registered person becomes the **owner** (admin, cannot be removed).
- **Accounts and their transactions** are visible and editable only to their
  owner – or to whom they were shared via **grants/joint accounts**.
- **Categories, budgets, savings goals, templates, rules and exchange rates**
  are likewise **separated per owner** (visible/editable only to owner +
  grantees). **Preset categories** stay readable for everyone (shared default
  categories); only an admin can change them.
- Receipts live **per owner** in storage.
- **Destructive maintenance RPCs** (wipe data, factory reset, cleanup) are
  reachable only via the server (Edge Functions with an admin check), not with
  the public client key.

To make it stricter/looser = adjust the RLS policies in
[`supabase/setup.sql`](supabase/setup.sql), the app stays the same.

## Data security & encryption

Short version: **yes, the data is protected** – not by keeping the key that is
visible in the web build secret, but by **server-side access rules**.

- **In transit:** all connections use **HTTPS/TLS** (encrypted on the wire).
- **At rest:** Supabase (Postgres + Storage) stores data **encrypted at rest
  (AES-256)**.
- **What lives in the public repo/web build is only the project URL + the
  `anon`/publishable key.** These are **public client values** – they sit in
  *every* web app in the browser and are **not a secret**. They alone grant no
  data access: every request is checked by **Row Level Security (RLS)** and the
  **email whitelist** in the database. Without an unlocked, signed-in account
  the API returns nothing.
- **Real secrets** (Supabase `service_role` key, GitHub archive token, archive
  encryption key) live **server-side only** in Supabase (function secrets /
  `archive_config`) and **never** in the repo or client. Archive files on
  GitHub are additionally **AES-256-GCM encrypted**.
- **Can third parties reach data via the public GitHub repo?** No. The repo
  holds only code + public client values, no financial data and no server
  secrets.

**Recommended extra hardening (in the Supabase dashboard, one-time):**
Authentication → Policies → **enable “Leaked password protection”** (checks
passwords against HaveIBeenPwned). Optionally also email confirmation and auth
rate limits.

## Release builds (install on devices)

> **Important:** pass the Supabase values on *every* build:
> `--dart-define-from-file=env.json` — otherwise the app only starts with the
> config hint.

The app name "Money Manager" + green € icon are set for Android/Windows/Web
(source `assets/icon/app_icon.png`, regenerate with
`dart run flutter_launcher_icons`).

### Android (APK for sideloading)
Requires: Android Studio (Android SDK) + once
`flutter doctor --android-licenses`.
```powershell
flutter build apk --release --dart-define-from-file=env.json
```
Result: `build\app\outputs\flutter-apk\app-release.apk` → copy to the phone and
install (allow 》Install from unknown sources《). For the Play Store, set up your
own keystore later.

### Windows (desktop)
Requires: Visual Studio with "Desktop development with C++" + Windows developer
mode.
```powershell
flutter build windows --release --dart-define-from-file=env.json
```
Result: `build\windows\x64\runner\Release\` — share the whole folder;
`money_manager.exe` starts the app.

### Windows MSIX installer (in addition to the .exe)
A proper installer with a Start menu entry and clean (un)installation.
1. Create a self-signed certificate once — instructions at the top of
   [`tool/build-msix.ps1`](tool/build-msix.ps1) (produces `windows/certs/mm.pfx` + `mm.cer`).
2. Build the installer: `.\tool\build-msix.ps1` → `build\windows\msix\MoneyManager.msix`.
3. On the recipient's machine, **trust `mm.cer` once**: right-click `mm.cer` →
   *Install certificate* → *Local Machine* → *Place all certificates in the
   following store* → *Trusted People*. Then **double-click `MoneyManager.msix`
   → Install**.

> `windows/certs/` (private key) is in `.gitignore` and is not committed.

## Feature set

The app is **feature-complete** – all planned expansion stages are
implemented:

- **Accounts & transactions:** multiple account types, archive, sorting,
  joint accounts/grants; income/expense/transfer, splits (incl. free-text
  label per item), templates, tags, receipt photos (compressed), calculator
  field, title suggestions, trash (30 days)
- **Analysis:** statistics (browsable periods, category breakdown, charts,
  heatmap, net-worth history), budgets, savings goals/envelopes (incl.
  round-up saving), recurring transactions + subscription detection, planning
  (available-to-spend, fixed costs, cashflow, what-if), debts,
  projects/trips, settle-up ("who owes whom"), **insights** (local & private,
  rule-based – no cloud LLM)
- **Data:** CSV export/import, PDF export, JSON backup, **archiving of old
  years** (encrypted to GitHub, see above), offline cache
- **Comfort & privacy:** bilingual **DE/EN**, dark mode + accent colors,
  app lock (PIN), **hide amounts** (quick toggle), search, activity feed,
  reminders/streak, multi-currency with exchange rates, **receipt OCR**
  (Android only, on-device)
- **Platforms:** Windows (.exe + signed MSIX), Android (APK), Web
  (responsive) + **PWA** ("Add to Home Screen", iPhone/Safari too)
- **Self-hosting & operations:** onboarding with your own Supabase
  connection, idempotent `setup.sql`, GitHub Pages deploy, **auto-sync for
  forks**, admin area (whitelist, users, roles, storage, maintenance),
  change/reset password
- **Quality:** unit/widget tests + GitHub Actions CI (analyze, format, test)
