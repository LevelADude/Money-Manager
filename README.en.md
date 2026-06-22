# Money-Manager

[🇩🇪 Deutsch](README.md) · 🇬🇧 **English**

Shared **finance bookkeeping for a small, trusted group** – a native app for
**Windows** and **Android** from a single codebase (Flutter). Each person keeps
their books separately, but every member can **see and edit** everyone else's
books. All devices sync live via **Supabase**.

> Status: **Foundation** – auth, books (create/list) and transactions
> (record/list/delete) with realtime sync are in place. See
> [Next steps](#status--roadmap).

## Tech stack

| Area           | Choice                                                   |
|----------------|----------------------------------------------------------|
| UI / client    | **Flutter** (Windows + Android, one codebase)            |
| Backend        | **Supabase** (Postgres, Auth, Realtime)                  |
| Permissions    | **Row Level Security** in the database                   |
| State mgmt     | **Riverpod**                                             |
| Navigation     | **go_router**                                            |

Why this stack? → [`docs/ARCHITECTURE.en.md`](docs/ARCHITECTURE.en.md)

## Screenshots

> Images live under [`docs/screenshots/`](docs/screenshots/) (instructions for
> creating them are there). Once available they appear here:

| Accounts | Transactions | Statistics |
|---|---|---|
| ![Accounts](docs/screenshots/01-konten.png) | ![Transactions](docs/screenshots/02-buchungen.png) | ![Statistics](docs/screenshots/04-statistik.png) |

## 🚀 Your own instance (no programming skills needed)

Want to run the app with **your own free database** – on phone, tablet, laptop or
desktop – without writing or building anything? Here's how, in a few minutes:

1. **Fork the repo.** Click **"Fork"** at the top right → the project is now in
   your GitHub account.
2. **Create a free Supabase project.** Sign up at
   [supabase.com](https://supabase.com) → **New Project** (Europe region
   recommended) → wait a moment until it's ready.
3. **Set up the database (1 click).** In the Supabase dashboard open the
   **"SQL Editor"**, paste the entire contents of
   [`supabase/setup.sql`](supabase/setup.sql) and click **"Run"**. (The app also
   offers this SQL text via a copy button on first launch.)
   - Optional, so registration works without email confirmation:
     **Authentication → Providers → Email → turn off "Confirm email".**
4. **Publish the website (GitHub Pages).** In your fork:
   **Settings → Pages → Source: "GitHub Actions".** Then under **Actions** run
   the **"Deploy Web (GitHub Pages)"** workflow once (or make a small commit).
   After ~2 minutes the site is reachable at
   `https://<your-name>.github.io/<repo-name>/`.
   - **Optional (auto-connect your site):** In **Settings → Secrets and variables
     → Actions** store the two secrets `SUPABASE_URL` and `SUPABASE_ANON_KEY`.
     Then *your* published site connects to your database automatically. Without
     the secrets the site starts empty and asks for the credentials in the
     onboarding (see step 5).
5. **Open the app & connect.** A fresh fork starts **empty** and shows the
   onboarding with two paths: **"New installation"** (your own empty DB) or
   **"Connect to an existing DB"**. Enter the **Supabase URL** and
   **anon/publishable key** (both in the Supabase dashboard under
   *Project Settings → Data API* and *API Keys*) → **"Connect & start"**.
   - **The first person to register automatically becomes the owner**
     (administrator with all rights – protected, cannot be removed).
   - Change/disconnect later: **More → Settings → Database connection**
     (this device only, your data is kept).

> **On iPhone:** open the site in **Safari** → **Share** → **"Add to Home
> Screen"**. Money Manager then launches like a real app (PWA). On Android the
> same works in Chrome ("Install app").

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
the schema from
[`supabase/migrations/0001_init.sql`](supabase/migrations/0001_init.sql), copy
the **Project URL** + **anon/publishable key**.

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
> `env.json` always takes precedence over values stored in the onboarding.

## Project structure

```
Money-Manager/
├── lib/
│   ├── main.dart                 # Supabase init + app start
│   ├── app.dart                  # MaterialApp.router
│   ├── config/                   # Supabase credentials (from env.json)
│   ├── core/                     # Router (auth redirect) + theme
│   ├── data/
│   │   ├── models/               # Profile, Ledger, AppTransaction
│   │   └── repositories/         # Supabase access + realtime streams
│   └── features/                 # auth / ledgers / transactions (UI + providers)
├── supabase/
│   ├── migrations/0001_init.sql  # Schema + RLS + Realtime
│   └── README.md                 # Backend setup
├── docs/ARCHITECTURE.md
├── tool/                         # run scripts
├── env.example.json              # template for env.json
└── ...                           # android/ · windows/ (generated by Flutter)
```

## Permission model

Deliberately simple for a **small, trusted group**: every signed-in member may
read **and** edit **all** books and transactions. Separation of the books is
organizational (each person's own books, visible via `owner_id` / `created_by`)
– not an access barrier. To make it stricter = only adjust the RLS policies in
`0001_init.sql`, the app stays the same.

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

## Status & roadmap

The full plan up to release is in [ROADMAP.en.md](ROADMAP.en.md).

- **Foundation & core:** ✅ auth, accounts (with types/categories + net worth),
  transactions (expense/income/transfer), categories, attribution, profile,
  Supabase + RLS + Realtime, offline cache (local-first)
- **Capture:** ✅ calculator field, title suggestions, receipts/photos,
  **tags**, **split transactions** (split across multiple categories)
- **Analysis:** ✅ transactions by **period** (day/week/month/year) with
  prev/next + totals, statistics (category breakdown, split-aware),
  budgets, recurring transactions, search/filter, **CSV & PDF export**
- **Platforms:** ✅ Windows (.exe + signed MSIX), Android (APK), Web
  (responsive) + **PWA** ("Add to Home Screen", iPhone/Safari too)
- **Self-hosting:** ✅ onboarding (your own Supabase connection), `setup.sql`,
  GitHub Pages deploy, end-user guide
- **Quality:** ✅ unit tests + GitHub Actions CI (analyze + test)
- **Admin:** ✅ flag in DB (1st user = admin), email whitelist, user
  management via Edge Function
- **Optional/future:** ⬜ multi-currency, password-reset flow, more charts
