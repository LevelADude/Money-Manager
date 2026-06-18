# Money-Manager

Gemeinsame **Finanz-Buchhaltung für eine kleine, vertraute Gruppe** – als
native App für **Windows** und **Android** aus einer einzigen Codebasis
(Flutter). Jede Person führt ihre Bücher getrennt, aber alle Mitglieder können
die Bücher der anderen **sehen und bearbeiten**. Alle Geräte werden über
**Supabase** live synchronisiert.

> Status: **Grundgerüst** – Auth, Bücher (anlegen/auflisten) und Buchungen
> (erfassen/auflisten/löschen) mit Realtime-Sync stehen. Siehe
> [Nächste Schritte](#nächste-schritte).

## Tech-Stack

| Bereich        | Wahl                                                     |
|----------------|----------------------------------------------------------|
| UI / Client    | **Flutter** (Windows + Android, eine Codebasis)          |
| Backend        | **Supabase** (Postgres, Auth, Realtime)                  |
| Berechtigungen | **Row Level Security** in der Datenbank                  |
| State-Mgmt     | **Riverpod**                                             |
| Navigation     | **go_router**                                            |

Warum dieser Stack? → [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md)

## Screenshots

> Die Bilder werden unter [`docs/screenshots/`](docs/screenshots/) abgelegt
> (Anleitung zum Erstellen dort). Sobald vorhanden, erscheinen sie hier:

| Konten | Buchungen | Statistik |
|---|---|---|
| ![Konten](docs/screenshots/01-konten.png) | ![Buchungen](docs/screenshots/02-buchungen.png) | ![Statistik](docs/screenshots/04-statistik.png) |

## 🚀 Eigene Instanz (ohne Programmierkenntnisse)

Du möchtest die App mit **deiner eigenen, kostenlosen Datenbank** nutzen – am
Handy, Tablet, Laptop oder Monitor – ohne etwas zu programmieren oder zu bauen?
So geht's in wenigen Minuten:

1. **Repo forken.** Oben rechts auf **„Fork"** klicken → das Projekt liegt jetzt
   in deinem GitHub-Konto.
2. **Kostenloses Supabase-Projekt anlegen.** Auf [supabase.com](https://supabase.com)
   registrieren → **New Project** (Region Europa empfohlen) → kurz warten, bis es
   fertig ist.
3. **Datenbank einrichten (1 Klick).** Im Supabase-Dashboard **„SQL Editor"**
   öffnen, den kompletten Inhalt von [`supabase/setup.sql`](supabase/setup.sql)
   einfügen und **„Run"** klicken. (Diesen SQL-Text bietet die App beim ersten
   Start auch per Kopier-Knopf an.)
   - Optional, damit die Registrierung ohne E-Mail-Bestätigung klappt:
     **Authentication → Providers → Email → „Confirm email" ausschalten.**
4. **Website veröffentlichen (GitHub Pages).** In deinem Fork:
   **Settings → Pages → Source: „GitHub Actions".** Dann unter **Actions** den
   Workflow **„Deploy Web (GitHub Pages)"** einmal starten (oder einen kleinen
   Commit machen). Nach ~2 Minuten ist die Seite unter
   `https://<dein-name>.github.io/<repo-name>/` erreichbar.
5. **App öffnen & verbinden.** Beim ersten Start fragt die App nach
   **Supabase-URL** und **anon/publishable Key** (beide findest du im
   Supabase-Dashboard unter *Project Settings → Data API* bzw. *API Keys*).
   Eingeben → **„Verbinden & starten"**. Fertig.
   - **Die erste Person, die sich registriert, wird automatisch Administrator.**

> **Auf dem iPhone:** Seite in **Safari** öffnen → **Teilen** → **„Zum
> Home-Bildschirm"**. Dann startet Money Manager wie eine echte App (PWA).
> Auf Android funktioniert das in Chrome genauso („App installieren").

> **Alternative zum Hosting:** Statt GitHub Pages kannst du den Ordner
> `build/web` (nach `flutter build web`) auch bei **Cloudflare Pages** oder
> **Netlify** hochladen – beides kostenlos und ohne eigenes Konto bei dritten
> nötig. GitHub Pages ist hier vorkonfiguriert und am einfachsten.

Die Zugangsdaten landen **nur lokal im Gerät** (bzw. Browser) – nicht im Code
und nicht auf GitHub. Jede Person/Instanz nutzt so ihre **eigene, getrennte
Datenbank**.

---

## Voraussetzungen (einmalig einrichten)

1. **Flutter SDK** – in diesem Projekt bereits nach `F:\flutter` installiert.
   Damit `flutter` überall funktioniert, `F:\flutter\bin` zur **PATH**-Umgebungs­variable
   hinzufügen (Windows-Suche → „Umgebungsvariablen bearbeiten").
2. **Für Android-Builds:** Android Studio (bringt Android SDK + Emulator mit).
   Danach einmalig `flutter doctor --android-licenses` ausführen.
3. **Für Windows-Desktop-Builds:**
   - **Visual Studio** (Community reicht) mit der Workload
     *„Desktopentwicklung mit C++"*.
   - **Windows-Entwicklermodus aktivieren** (für Plugin-Symlinks):
     Einstellungen → *für Entwickler* → **Entwicklermodus: Ein**
     (oder `start ms-settings:developers`).
4. Status prüfen mit:
   ```powershell
   flutter doctor
   ```

## Einrichtung

### 1. Supabase-Backend
Folge [`supabase/README.md`](supabase/README.md): Projekt anlegen, Schema aus
[`supabase/migrations/0001_init.sql`](supabase/migrations/0001_init.sql)
einspielen, **Project URL** + **anon/publishable Key** kopieren.

### 2. Zugangsdaten lokal hinterlegen
```powershell
Copy-Item env.example.json env.json
```
Dann `env.json` öffnen und deine Werte eintragen:
```json
{
  "SUPABASE_URL": "https://dein-projekt.supabase.co",
  "SUPABASE_ANON_KEY": "dein-anon-publishable-key"
}
```
`env.json` ist in `.gitignore` und wird **nicht** eingecheckt.

### 3. Abhängigkeiten holen
```powershell
flutter pub get
```

## Starten

```powershell
# Windows-Desktop
flutter run -d windows --dart-define-from-file=env.json
#   oder per Skript:
.\tool\run-windows.ps1

# Android (Gerät/Emulator muss in `flutter devices` auftauchen)
flutter run -d android --dart-define-from-file=env.json
#   oder per Skript:
.\tool\run-android.ps1
```

> Hinweis: `env.json` ist für die **eigene Entwickler-Instanz** der bequemste
> Weg (Zugangsdaten fest vorgegeben). Lässt man es weg, zeigt die App beim
> ersten Start das **Onboarding** und fragt URL + Key dort ab (siehe
> [Eigene Instanz](#-eigene-instanz-ohne-programmierkenntnisse)). `env.json` hat
> immer Vorrang vor im Onboarding gespeicherten Werten.

## Projektstruktur

```
Money-Manager/
├── lib/
│   ├── main.dart                 # Supabase-Init + App-Start
│   ├── app.dart                  # MaterialApp.router
│   ├── config/                   # Supabase-Zugangsdaten (aus env.json)
│   ├── core/                     # Router (Auth-Redirect) + Theme
│   ├── data/
│   │   ├── models/               # Profile, Ledger, AppTransaction
│   │   └── repositories/         # Supabase-Zugriff + Realtime-Streams
│   └── features/                 # auth / ledgers / transactions (UI + Provider)
├── supabase/
│   ├── migrations/0001_init.sql  # Schema + RLS + Realtime
│   └── README.md                 # Backend-Einrichtung
├── docs/ARCHITECTURE.md
├── tool/                         # run-Skripte
├── env.example.json              # Vorlage für env.json
└── ...                           # android/ · windows/ (von Flutter generiert)
```

## Berechtigungsmodell

Bewusst einfach für eine **kleine, vertrauenswürdige Gruppe**: Jedes angemeldete
Mitglied darf **alle** Bücher und Buchungen lesen **und** bearbeiten. Die
Trennung der Buchhaltungen ist organisatorisch (eigene Bücher je Person, sichtbar
über `owner_id` / `created_by`) – keine Zugriffssperre. Strenger machen =
nur die RLS-Policies in `0001_init.sql` anpassen, die App bleibt gleich.

## Release-Builds (auf Geräten installieren)

> **Wichtig:** Bei *jedem* Build die Supabase-Werte mitgeben:
> `--dart-define-from-file=env.json` — sonst startet die App nur mit dem
> Konfig-Hinweis.

App-Name „Money Manager" + grünes €-Icon sind für Android/Windows/Web gesetzt
(Quelle `assets/icon/app_icon.png`, neu generierbar mit
`dart run flutter_launcher_icons`).

### Android (APK zum Sideloaden)
Voraussetzung: Android Studio (Android SDK) + einmal
`flutter doctor --android-licenses`.
```powershell
flutter build apk --release --dart-define-from-file=env.json
```
Ergebnis: `build\app\outputs\flutter-apk\app-release.apk` → aufs Handy kopieren
und installieren (》Installation aus unbekannten Quellen《 erlauben). Für den
Play Store später einen eigenen Keystore einrichten.

### Windows (Desktop)
Voraussetzung: Visual Studio mit „Desktopentwicklung mit C++" + Windows-
Entwicklermodus.
```powershell
flutter build windows --release --dart-define-from-file=env.json
```
Ergebnis: `build\windows\x64\runner\Release\` — den ganzen Ordner weitergeben;
`money_manager.exe` startet die App.

### Windows-MSIX-Installer (zusätzlich zur .exe)
Richtiger Installer mit Startmenü-Eintrag und sauberem De-/Installieren.
1. Einmalig ein selbst-signiertes Zertifikat anlegen — Anleitung im Kopf von
   [`tool/build-msix.ps1`](tool/build-msix.ps1) (erzeugt `windows/certs/mm.pfx` + `mm.cer`).
2. Installer bauen: `.\tool\build-msix.ps1` → `build\windows\msix\MoneyManager.msix`.
3. Beim Empfänger **einmalig `mm.cer` vertrauen**: Rechtsklick auf `mm.cer` →
   *Zertifikat installieren* → *Lokaler Computer* → *Alle Zertifikate in folgendem
   Speicher* → *Vertrauenswürdige Personen*. Danach **`MoneyManager.msix`
   doppelklicken → Installieren**.

> `windows/certs/` (privater Schlüssel) steht in `.gitignore` und wird nicht eingecheckt.

## Status & Roadmap

Der vollständige Plan bis zum Release steht in [ROADMAP.md](ROADMAP.md).

- **Phase 1 – Grundgerüst:** ✅ Auth, Bücher, Buchungen, Supabase + RLS + Realtime
- **Phase 2 – Kernfunktionen:** ✅ Kategorien (verwalten + im Formular), Buchungen bearbeiten/löschen, Attribution („erfasst von …" / Besitzer), Profil (Anzeigename), Bücher verwalten (umbenennen/archivieren/löschen)
- **Phase 3 – Auswertungen & UX:** ⬜ Zeitraum-Filter, Summen + Kategorien-Aufschlüsselung, Diagramme, Suche, Lokalisierung
- **Phase 4 – Auth & Sicherheit:** ⬜ E-Mail-Bestätigung, Passwort-Reset, Session-Handling
- **Phase 5 – Qualität & Release:** ⬜ Tests, CI, App-Icon, Release-Builds (Windows MSIX, Android APK/AAB)
- **Phase 6 – Optional:** ⬜ wiederkehrende Buchungen, Belege, Budgets, Export, Mehrwährung
