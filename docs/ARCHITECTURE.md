# Architektur

🇩🇪 **Deutsch** · [🇬🇧 English](ARCHITECTURE.en.md)

## Überblick

```
┌───────────────────────────────┐        ┌──────────────────────────────────┐
│    Flutter-App (1 Codebase)    │        │             Supabase             │
│  ───────────────────────────   │  HTTPS │  ──────────────────────────────  │
│  Windows · Android · Web (PWA) │◀──────▶│  Postgres + Auth + Realtime      │
│  Riverpod · go_router · DE/EN  │  WSS   │  Storage + Edge Functions + RLS  │
└───────────────────────────────┘        └──────────────────────────────────┘
```

- **Eine** Dart-Codebasis → native Apps für **Windows** und **Android** plus
  **Web/PWA** (GitHub Pages).
- **Supabase** als Backend: Postgres, Auth (E-Mail/Passwort + Whitelist),
  Realtime (Live-Sync auf alle Geräte), Storage (Beleg-Fotos), Edge Functions
  (Admin-Wartung, Archiv-Proxy), RLS (Berechtigungen in der DB).

## Schichten in der App (`lib/`)

```
lib/
├── main.dart                 # Bootstrap: Konfig auflösen → Supabase-Init → App
├── app.dart                  # MaterialApp.router (Theme, Sprache, App-Sperre)
├── config/                   # Verbindungs-Auflösung (s. u.)
├── core/
│   ├── router.dart           # go_router inkl. Auth-Redirect
│   ├── main_scaffold.dart    # Bottom-Navigation (responsiv)
│   └── theme.dart            # Hell/Dunkel + Akzentfarben
├── data/
│   ├── models/               # Plain-Dart-Modelle (Account, AppTransaction,
│   │                         #   Budget, Category, RecurringRule, …)
│   ├── repositories/         # Supabase-Zugriff, EINE Repo-Klasse pro Domäne
│   └── local/app_cache.dart  # Offline-Cache (Local-First, SharedPreferences)
├── features/                 # je Feature ein Ordner: *_screen.dart (UI)
│   │                         #   + *_providers.dart (Riverpod)
│   └── accounts · transactions (+ocr) · statistics · budgets · savings ·
│       categories · recurring · planning · projects · debts · settle ·
│       sharing · currency · export · backup · insights · reminders ·
│       activity · search · archive · admin · profile · auth · onboarding ·
│       settings · simulator · more
├── shared/                   # wiederverwendbare Widgets/Helfer
│                             #   (MoneyText, Taschenrechner, Charts, …)
└── l10n/app_localizations.dart  # zentrale Übersetzungstabelle DE/EN
```

### Verantwortlichkeiten

| Schicht        | Aufgabe                                                        |
|----------------|---------------------------------------------------------------|
| **models**     | Typsichere Abbildung der DB-Zeilen, JSON-Konvertierung        |
| **repositories** | Einziger Ort, der mit dem Supabase-Client spricht           |
| **providers**  | Riverpod: hält Zustand, verbindet UI ↔ Repository, Streams    |
| **screens/widgets** | reine Darstellung + Nutzerinteraktion                    |

## Verbindungs-Auflösung (Self-Hosting)

Die App findet ihre Supabase-Verbindung in dieser Reihenfolge (höchste zuerst):

1. **Pro-Gerät-Override** – „Datenbank-Verbindung ändern" (Login/Profil) bzw.
   Onboarding; gespeichert in SharedPreferences.
2. **Committete `assets/db_connection/connection.json`** – bindet eine
   Instanz/einen Fork fest an ihre DB (funktioniert auf allen Plattformen).
   Im Upstream bewusst nur ein **Platzhalter** (`DEIN-PROJEKT…`, wird ignoriert),
   damit ein frischer Fork leer startet statt sich an die fremde DB zu binden.
3. **dart-define** – lokal `env.json`, im Web-Deploy GitHub-Secrets.
4. Nichts gesetzt → **Onboarding** (neue DB anlegen oder bestehende verbinden).

## State-Management: Riverpod (3.x)

- Repositories liefern **Cache-then-Stream**: beim Start sofort die letzten
  bekannten Daten aus dem Offline-Cache, dann der Realtime-Stream (Local-First).
- Pro Feature ein Provider-Satz; abgeleitete Werte (Salden, Statistik,
  Insights) werden **lokal** aus den gestreamten Buchungen berechnet.
- Eine Buchung vom PC erscheint auf dem Handy sofort – ohne manuelles
  Aktualisieren.

## Routing: go_router

- Nicht eingeloggt → `/login`; ein `redirect` beobachtet den Auth-Zustand.
- Eingeloggt → Bottom-Navigation (Konten · Buchungen · Statistik · Mehr) mit
  Unterrouten je Feature (z. B. `/more/archive`).
- Onboarding läuft **vor** der Riverpod-Initialisierung als eigene MaterialApp.

## Berechtigungsmodell

Zugang nur über die **E-Mail-Whitelist**; die erste registrierte Person wird
**Besitzer**. Konten + Buchungen sind per RLS auf **Besitzer + Freigaben/
Gemeinschaftskonten** beschränkt; Kategorien/Budgets/Sparziele sind bewusst
gruppenweit; Belege liegen pro Eigentümer. Zerstörerische Admin-Aktionen und
die Jahres-Archivierung laufen über **Edge Functions** (Secrets bleiben
serverseitig). Alles definiert in [`supabase/setup.sql`](../supabase/setup.sql).

## Warum dieser Stack?

- **Flutter**: eine Codebasis für Windows, Android **und** Web, echte native
  Builds, ausgereiftes offizielles Supabase-SDK.
- **Supabase**: Postgres (ideal für Finanzdaten: Summen, Integrität,
  Transaktionen), kostenloser Tier, Auth + Realtime + Storage eingebaut, RLS
  für Berechtigungen direkt in der DB statt fehleranfällig in der App.
- **Beträge als Integer-Cent**, Geldformat `de_DE` – keine Float-Rundungsfehler.
- **Privatsphäre**: Insights/OCR laufen 100 % lokal auf dem Gerät – bewusst
  kein Cloud-LLM.
