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

## ⬜ Phase E — Suche & Statistik
- Volltextsuche + Filter (Konto/Kategorie/Typ/Zeitraum/Betrag); **Statistik-
  Fenster** (Kategorie-Aufteilung, Verlauf, Einnahmen/Ausgaben, Vermögen über
  Zeit); Auswertung pro Woche/Monat/Jahr; Sparquote.

## ⬜ Phase F — Mehr Finanzfunktionen
- Budgets je Kategorie + Warnungen, wiederkehrende Buchungen, Tags, Split-
  Buchungen, Belege (Supabase Storage, komprimiert), Export (CSV/PDF).

## ⬜ Phase G — Qualität & Release
- Tests (Modelle/Repos/Sync), CI (GitHub Actions), App-Icon/Splash,
  Release-Builds (Windows MSIX, Android APK/AAB), Doku/Screenshots.

---

## Sparsam mit Supabase (Free-Plan)
DB-Speicher ist hier praktisch nie das Limit (Buchungen = winzige Zeilen). Die
realen Grenzen sind **Bandbreite** und die **7-Tage-Pause**. Gegenmaßnahmen:
Local-First (nur Deltas laden, Statistik lokal), Integer-Cent + kompakte Typen,
Nachschlagetabellen, selektives Realtime, Belege in Storage (nicht in der DB).
