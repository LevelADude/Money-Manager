# Money-Manager · Roadmap

Plan vom Grundgerüst bis zum fertigen, veröffentlichten Produkt. Jede Phase ist
in sich nutzbar; abgehakt wird erst, wenn die **Definition of Done** erfüllt ist.

Legende: ✅ fertig · 🔄 in Arbeit · ⬜ offen

---

## Phase 1 — Grundgerüst ✅

Fundament: Eine Codebasis (Flutter) für Windows + Android + Web, Supabase als
Backend mit Auth, Realtime-Sync und RLS.

- ✅ Flutter-Projekt (Windows, Android, Web)
- ✅ Supabase-Schema: `profiles`, `ledgers`, `categories`, `transactions`, View `ledger_balances`
- ✅ RLS (vertrauenswürdige Gruppe: alle dürfen alles) + Realtime + Security-Härtung
- ✅ Auth (Login/Registrierung), Bücher anlegen/auflisten, Buchungen erfassen/auflisten/löschen
- ✅ Konfiguration über `--dart-define-from-file`, CI-freie Validierung (`analyze`, `test`)

**Definition of Done:** App startet, verbindet sich mit Supabase, Login + erste Buchung funktionieren. ✔

---

## Phase 2 — Kernfunktionen vervollständigen 🔄

Aus dem Grundgerüst wird eine vollwertige Buchhaltung.

- 🔄 **Kategorien**: je Buch anlegen/löschen, Auswahl im Buchungsformular (gefiltert nach Einnahme/Ausgabe), Anzeige auf der Buchung
- 🔄 **Buchungen bearbeiten**: bestehende Einträge ändern (nicht nur neu/löschen)
- 🔄 **Attribution**: „erfasst von …" je Buchung, Eigentümer je Buch (Namen aus `profiles`)
- 🔄 **Profil**: Anzeigename ändern
- 🔄 **Ledger-Verwaltung**: umbenennen, archivieren/aktivieren, löschen (mit Bestätigung)

**Definition of Done:** Eine Buchung lässt sich vollständig pflegen (Kategorie,
Bearbeiten, Ersteller sichtbar); Bücher lassen sich verwalten.

---

## Phase 3 — Auswertungen & UX ⬜

Zahlen verständlich machen und die Bedienung verfeinern.

- ⬜ Zeitraum-Filter (Monat/Jahr/benutzerdefiniert) je Buch
- ⬜ Zusammenfassung: Summe Einnahmen/Ausgaben, Saldo, Aufschlüsselung pro Kategorie
- ⬜ Einfaches Diagramm (Balken/Donut) pro Kategorie/Monat
- ⬜ Suche & Sortierung der Buchungen
- ⬜ Archiv-Filter in der Bücherliste, Pull-to-Refresh, leere Zustände/Skeletons
- ⬜ Zentrale Texte (Lokalisierung de/en via `flutter_localizations` + `intl`)
- ⬜ Theme-Feinschliff, Dark-Mode-Umschalter, App-weite Fehler-/Lade-Zustände

**Definition of Done:** Nutzer sieht auf einen Blick Monatssalden und
Kategorien-Aufteilung; Buchungen sind durchsuchbar.

---

## Phase 4 — Auth & Sicherheit härten ⬜

- ⬜ E-Mail-Bestätigung sauber abbilden (Hinweis-Screen, Resend)
- ⬜ Passwort-Reset-Flow (Deep-Link/Redirect je Plattform)
- ⬜ Session-Handling: Auto-Refresh, „abgemeldet"-Zustände, Fehlerbanner bei Offline
- ⬜ Optionales strengeres Berechtigungsmodell (z. B. private Bücher + explizites Teilen) — nur RLS-Policies + kleine UI
- ⬜ Rate-Limit-/Fehlermeldungen benutzerfreundlich übersetzen

**Definition of Done:** Registrierung, Bestätigung und Passwort-Reset
funktionieren auf allen Zielplattformen; Sitzungsverlust wird sauber behandelt.

---

## Phase 5 — Qualität & Release ⬜

- ⬜ Tests: Unit (Models/Repos mit Mock-Client), Widget-Tests der Screens, 1 Integrationstest gegen Test-Supabase
- ⬜ CI: GitHub Actions (`flutter analyze` + `flutter test`) bei jedem Push/PR
- ⬜ App-Icon, Splash-Screen, Branding (`flutter_launcher_icons`)
- ⬜ Release-Builds: **Windows** (MSIX o. Installer), **Android** (signiertes APK/AAB)
- ⬜ Versionierung/Changelog, Release-Workflow dokumentiert
- ⬜ README/Doku finalisieren (Screenshots, Installationsanleitung für Endnutzer)

**Definition of Done:** Installierbare Builds für Windows + Android liegen vor,
CI ist grün, Doku ist vollständig.

---

## Phase 6 — Optional / Zukunft ⬜

Erweiterungen nach Bedarf:

- ⬜ Wiederkehrende Buchungen (Daueraufträge)
- ⬜ Belege/Anhänge (Supabase Storage)
- ⬜ Budgets pro Kategorie + Warnungen
- ⬜ Export (CSV/PDF), Import
- ⬜ Mehrwährung mit Umrechnung
- ⬜ Audit-Log / Änderungsverlauf je Buchung
- ⬜ Mehrere Mandanten/Gruppen

---

## Technische Schulden & Notizen

- `passkeys`-Konsolenwarnung im Web ist harmlos (ungenutzte Transitiv-Abhängigkeit von `supabase_flutter`).
- `profiles` ist bewusst **nicht** in der Realtime-Publication (selten geändert; wird per Einmal-Abfrage geladen).
- Windows-Desktop-Build erfordert VS-Workload „Desktopentwicklung mit C++" + Entwicklermodus.
- RLS ist aktuell offen für alle Mitglieder — gewollt; Verschärfung ist reine Policy-Änderung (siehe Phase 4).
