# Redesign „Smaragd Glass" – Fortschritt

Arbeitsgedächtnis für das Redesign. Zuerst lesen, dann dort weitermachen.
Branch: `feat/redesign-smaragd-glass`. Vorlagen: `design/prototypen/`.

## Erledigt

- **Phase 1** – Paletten, `AppColors`, Komponenten-Themes, `AppBackdrop`,
  `Glass`/`PressScale`, Glas-Navigation, Paletten-Auswahl.
- **Phase 2 Teil 1** – Logo/Icons, Palettenfarben statt `Colors.green/red`,
  Scrollen unter der Glas-Leiste, Sheets über den Root-Navigator, Inter.
- **Phase 2 Teil 2** – vier Hauptscreens als Bento:
  - `lib/shared/bento.dart`: `BentoTile`, `BentoStat`, `BentoGlyph`,
    `BentoRow`, `BentoList`, `BentoSectionHeader`, `BentoChip`, `BentoGrid`
    (2 Spalten schmal, 4 breit), `BentoColumns`, Stile in `Bento`.
  - `AppColors.chartSeries(context)`: Diagrammfarben aus der Palette.
  - Konten, Buchungen (Version C), Statistik, Mehr umgebaut.
  - `MainScaffold` meldet die Glas-Leiste auch als `viewPadding`, damit
    schwebende Knöpfe/Snackbars verschachtelter Scaffolds darüber liegen.
  - Vorschau ohne Login: `lib/dev_preview.dart` (echte Shell + echte
    Screens), Beispieldaten/Overrides in `lib/dev_preview_data.dart`.
  - Tests: `test/bento_test.dart`, `test/main_screens_test.dart`.

- **Phase 2 Teil 3** – Glas-Sheets: `showGlassSheet` in
  `lib/shared/glass.dart` (dickes Glas, Griff, Root-Navigator) ist die
  einzige Stelle, die Bottom-Sheets öffnet; alle sieben Aufrufe umgestellt
  (Verlauf, Vorlagen, Belegquelle, Reservierung einlösen, Währung,
  Statistik-Aufschlüsselung, Rechner). Test: `test/glass_sheet_test.dart`.
  Vorschau: langer Druck auf den Paletten-Knopf öffnet ein Beispiel-Sheet.

- **Phase 3 (Teil 1)** – übrige Screens, zentrale Angleichung:
  - `AppColors.warning` ersetzt alle harten Orange-Töne (Budgets, Schulden,
    Erinnerungen, Reservierungen).
  - `Card` ist über das Theme bündig wie eine Bento-Kachel; Listenränder
    einheitlich über `BentoListView.paddingOf(context)`.
  - Neu in `bento.dart`: `BentoSegment`/`BentoListView` (träge Liste als
    eine Kachel), `bentoSections` (Abschnitte mit `Divider` werden Kacheln).
  - Als Kachel-Listen: Aktivität, Papierkorb, Daueraufträge, Archivjahr,
    Projekte, Regeln, Meine Summen, Suche, Reservierungen, Kontodetail,
    Kategorien. Als Abschnitts-Kacheln: Einstellungen, Backup, Admin.
  - Beträge rechts in `ListTile` kräftiger (Theme).
  - Vorschau und Tests um sechs Unterseiten erweitert.

- **Phase 3 (Teil 2, lokal 2026-11-16)** – Profil und „Jahre archivieren"
  als Abschnitts-Kacheln (`bentoSections`); beide in Vorschau
  (`#/more/profile`, `#/more/archive`) und Tests. Verlaufslinie
  (`MiniLineChart`): Endpunkt wird nicht mehr angeschnitten, Fläche reicht
  bis zum Rand, `shouldRepaint` vergleicht statt immer neu zu zeichnen.
  Im Bild geprüft (Salbei, breit).

- **Phase 3 (Teil 3, lokal 2026-11-16)** – Formulare Konto, Dauerauftrag,
  Reservierung: Eingabefelder bleiben eigene Flächen (Kachelfarbe + Rand
  aus dem Theme); alles, was lose auf dem Hintergrund lag (Schalter,
  Datumszeilen, Rhythmus, Freigabe-Chips), sitzt in `BentoGroup`-Kacheln.
  `bentoSections` baut jetzt ebenfalls auf `BentoGroup`. Auswahlfelder mit
  `isExpanded` und gekürzten Namen: vorher lief ein langer Konto- oder
  Kategoriename auf schmalen Geräten rechts über. Alle drei in der
  Vorschau (`#/account/new`, `#/more/recurring/new`,
  `#/more/reservations/new`) und in den Tests (schmal + breit). Im Bild
  geprüft: schmal, je eine Palette (Reservierung Salbei inkl. Aufstocken,
  Dauerauftrag Dunkel, Konto Smaragd); breit nur per Test.

- **Phase 3 (Teil 4, lokal 2026-11-16)** – Buchungsformular: Schalter
  „Aufteilen" samt Teilzeilen, Beleg (Bild + Aktionen), Datumszeile und
  Kommentare (nur beim Bearbeiten) je in einer `BentoGroup`-Kachel; der
  Trennstrich vor den Kommentaren entfällt. Konto- und Zielkonto-Auswahl
  mit `isExpanded` und gekürzten Namen. Kommentar-Eingabe nutzt das
  Feld-Theme statt eigenem Rahmen. Typ-Umschalter unter 420 px Breite nur Text (mit Symbol brach „Einnahme“ im Wort um). Im Bild geprüft: schmal, alle drei Paletten; breit und Beleg-Kachel mit Bild nur per Test bzw. gar nicht. In Vorschau (`#/transactions/new`,
  `#/transactions/tx0`) und Tests (schmal + breit).

- **Phase 4 (Messung + belegte Maßnahme)** – Stand 2026-11-15, Flutter
  3.44.2, `flutter build web --release`:

  | Messwert | vorher | nachher |
  |---|---|---|
  | `main.dart.js` | 5.055.746 B (gzip 1.449.050) | 5.056.904 B |
  | `Inter.ttf` | 876.576 B (gzip 461.298) | 525.856 B (gzip ca. 276.000) |
  | Wasm-Build (`--wasm`) | schlägt fehl | unverändert |

  - Inter gekürzt mit `tool/subset-inter.sh` (Latein erweitert, Griechisch,
    Kyrillisch, Satz-/Währungs-/Pfeilzeichen; Achsen `opsz`/`wght` bleiben).
    Geprüft: jedes im Code vorkommende Zeichen, das Inter hatte, ist noch da.
  - Wasm scheitert an der transitiven Abhängigkeit `ua_client_hints` 1.7.0
    (`dart:html`). Deploy-Workflow deshalb NICHT geändert.
  - Ladeanzeige und Onboarding nutzen jetzt die gespeicherte Palette statt
    Material-Standard (kein Farbsprung beim Start).
  - Nicht gemessen: Startzeit und Scroll-Flüssigkeit der echten App (kein
    Login in der Cloud). Glas-Unschärfe: weiterhin nur Navigation und
    Sheets, nie in Listenzeilen (per Test abgesichert).

## Nächste Schritte (Reihenfolge)

1. Phase 3 (Rest) – noch nicht einzeln angefasst:
   Login/Passwort-Reset, Onboarding,
   Export/Import, Archiv-Einrichtung, Insights, Simulator, Freigaben,
   Budgets/Sparziele/Schulden/Planung im Detail (nutzen `Card` und sind über
   das Theme bereits angeglichen). `pdf_export.dart` behält feste Farben
   (Papier, kein UI).
2. Phase 4 (Rest) – Wasm erst nach Update/Ersatz von `ua_client_hints`
   erneut prüfen; Startzeit mit echten Daten messen.
3. Phase 5 – Abschlussprüfung (Kontrast, Abstände, Fokus/Tastatur,
   reduzierte Bewegung) und Optimierungs-Checkliste.

Kein PR nach `main` und kein Merge ohne ausdrückliche Freigabe des Nutzers.

## Prüfen nach jeder Phase

```bash
dart format --output=none --set-exit-if-changed lib test
flutter test
flutter build web --release
```

Sichtprüfung: `flutter build web --release --no-web-resources-cdn -t
lib/dev_preview.dart`, dann im Browser `?p=sage|emerald|dark#/`,
`#/transactions`, `#/statistics`, `#/more`.

## Entscheidungen (Phase 2 Teil 2)

- Beträge: Einnahmen in Einnahmenfarbe, Ausgaben neutral (wie Prototyp);
  Saldo und Vermögen nur bei negativem Wert in Ausgabenfarbe.
- Konten: Gesamtsaldo-Kachel mit 12-Monats-Verlauf und Veränderungs-Marke
  aus `netWorthHistoryProvider` (vorhandene Daten, keine neue Abfrage).
  Konten je Typ in einer Listen-Kachel, Typ und Zwischensumme darüber.
  Breit: Saldo links, Summen rechts, Kontogruppen zweispaltig.
- Buchungen: Zeitraum-Umschalter und Blättern bleiben stehen; Summen,
  Suche, Tags und Tage scrollen gemeinsam. Tageskopf zeigt zusätzlich den
  Tagessaldo. Ohne Kategorie: Pfeil-Icon im Kreis, Umbuchung: Tausch-Icon.
  Breit: Kategorie und Konto als eigene Spalten.
- Statistik: Kennzahlen (auch Vermögen/Schulden) als Summen-Kacheln oben,
  Diagramme breit zweispaltig. Feste Diagrammfarben durch Palettenreihe
  ersetzt (8 Farben, danach Wiederholung).
- Mehr: sechs Gruppen ohne Überschriften (keine neuen Texte): Finden,
  Auswerten/Planen, Ziele/Schulden, Automatik, Daten, Konto/App.

## Entscheidungen (Phase 2 Teil 3)

- Dialoge (`AlertDialog`, Datumswahl) bleiben deckende Kacheln: Glas ist
  laut Designregel der Bedienebene vorbehalten (Tableiste, Kopfzeile,
  Sheets, Plus-Knopf); Bestätigungen zu Geld und Löschen sollen maximal
  lesbar sein. Form und Farben kommen schon aus `dialogTheme`.
- Sheet-Inhalt bekommt ein eigenes durchsichtiges `Material`, damit
  Listenzeilen ihre Tinte auf dem Glas malen.

## Ungeprüft / offen

- Phase 3: nur Kontodetail, Meine Summen, Suche, Projekte, Reservierungen
  und Einstellungen im Bild geprüft; die übrigen umgestellten Screens
  (Admin, Backup, Kategorien, Papierkorb, Aktivität, Daueraufträge, Regeln,
  Archivjahr) nur über Analyse und Build, da sie Login-Daten brauchen.

- Die sieben echten Sheets nur per Test/Beispiel-Sheet geprüft, nicht
  einzeln im Bild (brauchen Login bzw. Formulardaten).
- Nur Web (Chromium, Vorschau mit Beispieldaten) geprüft; nicht Windows,
  nicht Android, nicht mit echten Daten/Login.
- Englische Texte, „Beträge verbergen", Fremdwährungen und Reservierungen
  nicht im Bild geprüft (Code unverändert übernommen).
- Diagrammfarben wiederholen sich ab der 9. Kategorie.
- Bei extrem schmaler Breite (unter ca. 200 px) läuft die Kopfzeile der
  Konten-Seite über; für echte Geräte ohne Belang.
