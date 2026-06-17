# Money-Manager · Roadmap

Vollwertige **Personal-Finance-App** für eine kleine, vertrauenswürdige Gruppe –
eine Flutter-Codebasis für **Windows · Android · Web**, Backend **Supabase**.

**Architektur-Entscheidungen:** Local-First + Delta-Sync (bandbreitenschonend,
offline) · Konten gehören Personen, alle dürfen alles, Ansichten **pro Person
trennbar** · Kategorien **gruppenweit** geteilt · Beträge als **Integer Cent**.

Legende: ✅ fertig · 🔄 in Arbeit · ⬜ offen

---

## ✅ Phase 1 — Grundgerüst
Auth, Supabase (Postgres/Auth/Realtime/RLS), erste Buchungen, Multi-Plattform.

## ✅ Phase 2 — Kernfunktionen (v1)
Kategorien, Buchung bearbeiten/löschen, Attribution, Profil.

## ✅ Phase A — Datenmodell v2 (Personal-Finance)
- `accounts` (Kontotypen, Anfangssaldo-Cent, Icon/Farbe, Kreditlimit, „zählt zum
  Vermögen", Archiv) ersetzt `ledgers`.
- `transactions` mit Typ **Ausgabe/Einnahme/Übertrag**, `amount_cents`, Titel,
  `transfer_account_id`, `deleted_at`-Tombstones.
- `categories` **gruppenweit** + umfangreiches **Preset** (Migration 0003).
- `account_balances`-View; UI: Kontoliste je Person + **Gesamtvermögen**,
  Konto-Detail mit Saldo, Buchungsformular mit Typen/Übertrag/Titel/Notiz,
  gruppenweite Kategorienverwaltung.

## ✅ Phase B — Local-First (Offline-Cache)
- Persistenter Offline-Cache (`shared_preferences`, plattformübergreifend) über
  dem Supabase-Realtime-Stream: **sofortiger und offline-fähiger Start** mit den
  letzten bekannten Daten, automatische Persistenz bei jedem Update.
- Korrektheit bleibt beim erprobten Stream (wichtig für Finanzdaten). Eine reine
  Delta-Synchronisation zur weiteren Bandbreiten-Reduktion ist optional/später —
  für eine kleine Gruppe nicht nötig (Bandbreite ist nicht der Engpass).

## ⬜ Phase C — Konten-Feinschliff
- Icon/Farb-Auswahl je Konto, Reihenfolge, Personen-Filter in der Übersicht,
  Schulden-/Kredit-Übersicht (Verbindlichkeiten getrennt), Kontowährung.

## ⬜ Phase D — Buchung-Komfort
- **Taschenrechner im Betragsfeld** (Teilsummen), **Titel-Autovervollständigung**
  (+ Kategorie-Vorschlag bei bekanntem Titel), Korrektur-/Saldoabgleich-Buchung,
  Icon/Farbe je Kategorie + Unterkategorien.

## ✅ Phase E — Suche & Statistik
- **Suche** über alle Buchungen (Titel/Notiz/Kategorie) + Typ-Filter
  (Ausgabe/Einnahme/Übertrag) → Treffer öffnen direkt die Buchung.
- **Statistik-Fenster**: Zeitraum (Monat/Jahr/Gesamt), Summen
  Einnahmen/Ausgaben/Saldo, **Kategorie-Aufschlüsselung als Balken**,
  Gesamtvermögen + Schulden. Alles lokal gerechnet.
- Offen/später: Wochenansicht + benutzerdefinierter Zeitraum, Verlaufskurve,
  Sparquote.

## 🔄 Phase F — Mehr Finanzfunktionen
- ✅ **Budgets** je Kategorie (Monatsbudget, Fortschritt + Überschreitungs-Warnung,
  Migration 0004).
- ✅ **Wiederkehrende Buchungen** (Daueraufträge): Regeln je Konto, Intervall
  Tag/Woche/Monat/Jahr, Start-/Enddatum; **race-sichere Auto-Generierung** beim
  App-Start (atomares Beanspruchen der Periode → keine Doppelbuchungen); Migration 0005.
- ✅ **CSV-Export** + **Belege/Fotos** je Buchung (Supabase Storage, komprimiert).
- ✅ **Admin-Bereich + E-Mail-Whitelist**: Registrierung nur für freigeschaltete
  E-Mails, Nutzerübersicht/-verwaltung, Admin-Rechte, Nutzer löschen (Edge Function).
- ⬜ Tags, Split-Buchungen, PDF-Export.

## 🔄 Phase G — Qualität & Release
- ✅ **App-Icon** (grünes €, Android/Windows/Web) + App-Name „Money Manager".
- ✅ **Release-Builds erfolgreich erzeugt**: Windows (`money_manager.exe`, ~32 MB)
  + Android (`app-release.apk`, ~54 MB). Build-Fixes: `kotlin.incremental=false`
  (Projekt F: ↔ Pub-Cache C:), Gradle-Heap 4G/Metaspace 1G (OOM), `compileSdk 36`
  global für alle Plugin-Subprojekte. Anleitung in der README.
- ✅ **Windows-MSIX-Installer** (signiert; `tool/build-msix.ps1`).
- ✅ **Taschenrechner-Tastenfeld** + **Menüleiste** (Tabs) + Konten nach Kategorie.
- ⬜ Tests (Modelle/Repos), CI (GitHub Actions), Screenshots.

---

## Sparsam mit Supabase (Free-Plan)
DB-Speicher ist hier praktisch nie das Limit (Buchungen = winzige Zeilen). Die
realen Grenzen sind **Bandbreite** und die **7-Tage-Pause**. Gegenmaßnahmen:
Local-First (nur Deltas laden, Statistik lokal), Integer-Cent + kompakte Typen,
Nachschlagetabellen, selektives Realtime, Belege in Storage (nicht in der DB).
