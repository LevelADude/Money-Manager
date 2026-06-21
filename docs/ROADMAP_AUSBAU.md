# Money-Manager — Ausbau-Roadmap (Feature-Phasen O–W)

Aufbauend auf dem fertigen Kern (Konten, Buchungen, Kategorien, Tags, Splits,
Budgets, Daueraufträge, Statistik mit Diagrammen, CSV/PDF-Export, Onboarding/
Self-Hosting, PWA, native Builds). Diese Roadmap setzt das genehmigte
Brainstorming um. Reihenfolge: schnelle Gewinne zuerst, dann Daten/Sicherheit,
Zusammenarbeit, Smart-Features, zuletzt die großen Brocken.

**Geparkt (vorerst NICHT bauen):** Geo/Standort, echte Bank-Anbindung (FinTS/
Plaid). CSV-*Import* bleibt drin.

Arbeitsweise je Feature: `flutter analyze` = 0, Tests grün, Commit/Push. Native
Builds + Web werden am Ende jeder Phase (oder gesammelt) neu gebaut.

---

## Phase O — UX-Schnellgewinne 🟢
- O1 Dark Mode + wählbare Akzentfarbe (Theme in Einstellungen, persistiert)
- O2 App-Sperre (PIN/Biometrie) + „Beträge verbergen"-Schalter
- O3 Globale Suche (Buchungen, Konten, Notizen, Tags)
- O4 Konten anheften / Reihenfolge (analog Kategorien-Sortierung)
- O5 Buchung duplizieren + Vorlagen/Favoriten
- O6 Statistik: Top-Ausgaben, Vergleich Vormonat/Vorjahr, Drill-down (Diagramm → Liste)
- O7 Pro-Person-Filter überall (Buchungen/Statistik nach Besitzer)

## Phase P — Budgets & Prognose 🟡
- P1 Budget-Fortschritt sichtbar (Ringe/Balken, Warnung bei Überschreitung)
- P2 „Verfügbar bis Monatsende" + Fixkosten-Übersicht (aus Daueraufträgen)
- P3 Forecast/Hochrechnung (Ausgabentempo → Monatsende)
- P4 Cashflow-Kalender (erwartete Ein-/Ausgaben + Saldo-Prognose)

## Phase Q — Sparen & Schulden 🟡
- Q1 Sparziele (Zielbetrag/Termin/Fortschritt, Beiträge zuordnen)
- Q2 Umschläge/Töpfe (Envelope-Budgeting)
- Q3 Rundungs-Sparen (Aufrunden → Sparkonto)
- Q4 Schulden-/Kredit-Tracker (Tilgungsplan, Restschuld-Verlauf)
- Q5 „Wer schuldet wem" (gegenseitige Auslagen + Ausgleichsvorschlag)

## Phase R — Auswertung erweitern 🟡
- R1 Vermögensverlauf (Linien-/Flächendiagramm über Zeit)
- R2 Heatmap (Ausgaben pro Tag im Kalender)
- R3 Sankey-/Flussdiagramm (Einnahmen → Kategorien)

## Phase S — Daten & Sicherheit 🟢🟡
- S1 Papierkorb (gelöschte Buchungen 30 Tage wiederherstellbar; Soft-Delete existiert)
- S2 Backup/Restore (kompletter JSON-Export + Re-Import)
- S3 Audit-Log/Verlauf je Buchung (wer/wann/was)
- S4 E-Mail-Bestätigung & Passwort-Reset-Flow in der App

## Phase T — Zusammenarbeit 🟡
- T1 Aktivitäts-Feed (wer hat was gebucht/geändert)
- T2 Kommentare an Buchungen
- T3 Rollen/Rechte feiner (nur-lesen-Mitglieder)

## Phase U — Erinnerungen 🟡
- U1 Lokale Benachrichtigungen (Dauerauftrag fällig, Budget zu 90 %, Beleg fehlt)
- U2 Tägliche Erfassungs-Erinnerung + Streak

## Phase V — Automatisierung & Smart 🟡🔴
- V1 CSV-Import (Mapping-Assistent, Gegenstück zum Export)
- V2 Regeln / Auto-Kategorisierung (Titel/Händler → Kategorie, lernend)
- V3 Wiederkehrende Erkennung (Abos automatisch erkennen)
- V4 Beleg-Scan mit OCR (Betrag/Datum/Händler vorausfüllen) — ✅ Android (on-device, ML Kit); Windows/Web: manuelle Eingabe
- V5 Was-wäre-wenn-Simulator (Sparrate ändern → Jahresauswirkung)
- V6 KI-Insights (siehe unten) — ✅ Stufe 1 (lokal, regelbasiert); Stufe 2 (LLM) bewusst nicht umgesetzt (Kosten/Datenschutz)

## Phase W — Internationalisierung, Mehrwährung & Komfort 🔴
- W1 Mehrsprachigkeit DE/EN (Flutter-Localization)
- W2 Mehrwährung (Konto/Buchung + Wechselkurse, Reise-Modus)
- W3 Reise-/Projekt-Sicht (eigene Auswertung je Projekt-Tag)
- W4 Quick Actions / Home-Screen-Widget (Schnellerfassung)

---

## KI-Insights — wie es funktionieren würde (Phase V6)

Zwei Stufen, nacheinander baubar:

**Stufe 1 — Regelbasiert/statistisch (lokal, kostenlos, datensparsam).**
Aus den ohnehin geladenen Buchungen werden Kennzahlen berechnet und als
Klartext-Karten gezeigt, z. B.:
- Monatsvergleich je Kategorie: „Essen +32 % ggü. Ø der letzten 3 Monate".
- Anomalie-Erkennung: Buchung > (Mittelwert + 2·Standardabw.) der Kategorie → „ungewöhnlich hoch".
- Abo-/Wiederkehr-Erkennung: gleicher Titel/Betrag in regelmäßigem Abstand → „mögliches Abo, 12 €/Monat".
- Trend/Forecast: lineare Hochrechnung Richtung Monatsende.
- Sparquote: (Einnahmen − Ausgaben) / Einnahmen, mit Verlauf.
Vorteil: keine Kosten, keine Daten verlassen das Gerät, funktioniert offline.

**Stufe 2 — Optionale echte LLM-Zusammenfassung (opt-in).**
Aggregierte, anonymisierte Kennzahlen (keine Rohbuchungen/Klarnamen) werden an
ein LLM (z. B. Claude API) geschickt, das einen monatlichen Bericht in
natürlicher Sprache + konkrete Tipps formuliert. Eigener API-Key in den
Einstellungen (passt zum Self-Hosting-Konzept), klar opt-in, mit Hinweis was
gesendet wird. Aufruf serverseitig über eine Supabase Edge Function, damit der
Key nicht im Client liegt.

Empfehlung: Mit Stufe 1 starten (sofort nützlich, kostenlos); Stufe 2 später als
optionales Extra.
