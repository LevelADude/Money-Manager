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

> Wichtig: Die App liest die Supabase-Zugangsdaten ausschließlich über
> `--dart-define-from-file`. Ohne dieses Flag (bzw. ohne `env.json`) zeigt sie
> einen Konfigurations-Hinweis statt zu starten.

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
`money_manager.exe` startet die App. (Optional später: MSIX-Installer via
`msix`-Paket.)

## Status & Roadmap

Der vollständige Plan bis zum Release steht in [ROADMAP.md](ROADMAP.md).

- **Phase 1 – Grundgerüst:** ✅ Auth, Bücher, Buchungen, Supabase + RLS + Realtime
- **Phase 2 – Kernfunktionen:** ✅ Kategorien (verwalten + im Formular), Buchungen bearbeiten/löschen, Attribution („erfasst von …" / Besitzer), Profil (Anzeigename), Bücher verwalten (umbenennen/archivieren/löschen)
- **Phase 3 – Auswertungen & UX:** ⬜ Zeitraum-Filter, Summen + Kategorien-Aufschlüsselung, Diagramme, Suche, Lokalisierung
- **Phase 4 – Auth & Sicherheit:** ⬜ E-Mail-Bestätigung, Passwort-Reset, Session-Handling
- **Phase 5 – Qualität & Release:** ⬜ Tests, CI, App-Icon, Release-Builds (Windows MSIX, Android APK/AAB)
- **Phase 6 – Optional:** ⬜ wiederkehrende Buchungen, Belege, Budgets, Export, Mehrwährung
