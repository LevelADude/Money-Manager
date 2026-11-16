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

1. Phase 3 (Rest) – erledigt (Teil 5): Login, Passwort-Reset, Onboarding
   (Nebenwege des Logins als Listen-Kachel, Auswahl und Schritte des
   Onboardings als Kacheln, Felder frei darunter, Autofill-Hinweise;
   Vorschau: `#/login`, `#/reset-password`, `#/onboarding`). Der
   Verbindungs-Dialog bleibt ein deckender Dialog (siehe Entscheidungen).
   Teil 6 (2026-11-16): Export und CSV-Import als Kacheln (Hinweis-Kachel
   mit Glyphe, Export-Aktionen als Listen-Kachel, ohne Buchungen gedimmt;
   CSV-Vorschau als Kachel, scrollt mit der Seite; Import-Status als
   Kachel, Ladekreis im Knopf). Vorschau: `#/more/export`, `#/more/import`.
   Teil 7 (2026-11-16): Insights, Simulator, Archiv-Einrichtung.
   Insights: Umschalter bleibt stehen, je Abschnitt eine Listen-Kachel,
   Zeilen mit Kreis in Signalfarbe (`BentoGlyph(tint:)`), vollem Text und
   optionaler Verlaufslinie bündig mit dem Text. Simulator: Hinweis-Kachel,
   Felder frei (breit nebeneinander), Regler in einer Kachel, zwei
   Summen-Kacheln, Vermögens-Kachel wie die Gesamtsaldo-Kachel (Marke und
   Linie nur bei Veränderung). Behoben: Vorbelegung las die Monatswerte nur
   einmal und blieb bei 0, wenn Buchungen noch luden. Archiv-Einrichtung:
   Status und Erklärung in einer Hinweis-Kachel (Häkchen in
   Einnahmenfarbe), Felder im Theme-Stil, Ladekreis im jeweiligen Knopf.
   Vorschau: `#/more/insights`, `#/more/simulator`, `#/more/archive/setup`.
   Teil 8 (2026-11-16): Budgets, Sparziele, Schulden. Neuer Baustein
   `BentoProgress` (runder Balken, Spur in getönter Signalfarbe). Budgets:
   Gesamtbudget- und Verplant-Kachel (breit nebeneinander, Zahl und Balken
   auf einer Linie), Kategorien mit Budget als Listen-Kachel (Prozent in der
   Titelzeile, Balken und Stand bündig mit dem Namen, Antippen bearbeitet),
   Kategorien ohne Budget als zweite Listen-Kachel ("Dieser Monat: Betrag"
   plus Knopf; die Texte `noBudgetThisMonth/Week` entfallen). Sparziele: je
   Ziel eine Kachel (breit zweispaltig), Betrag groß, Knopf unten. Schulden:
   Summen-Kachel, je Konto eine Kachel mit Auslastung und Verlauf
   (`MiniLineChart` statt eigenem Painter, der immer neu zeichnete).
   Behoben: Betrag im `FittedBox` wurde für die Rasterhöhe zweizeilig
   gemessen (Kachel zu hoch), jetzt `maxLines: 1`. Vorschau:
   `#/more/budgets`, `#/more/goals`, `#/more/debts` (Beispiel-Budgets,
   -Sparziele, Kreditrahmen 1.500 €).
   Teil 9 (2026-11-16): Planung, Cashflow, Abrechnen, Erinnerungen,
   Freigaben – damit ist Phase 3 abgeschlossen. Planung: Verfügbar- und
   Hochrechnungs-Kachel (breit nebeneinander, Vormonatsvergleich als Marke),
   Fixkosten als Listen-Kachel mit Summe in der Überschrift. Cashflow: Saldo
   und Tiefststand als Summen-Kacheln, Warnung als Hinweis-Kachel,
   Ereignisse als Listen-Kachel (Einnahmen in Einnahmenfarbe, Ausgaben
   neutral, laufender Saldo darunter). Abrechnen: zwei Summen-Kacheln,
   Salden und Ausgleich als Listen-Kacheln (breit nebeneinander). Erinnerungen:
   Streak-Kachel, Hinweise als Listen-Kachel mit Kreis in Signalfarbe und
   ganzem Text (`BentoRow.subtitleMaxLines`). Freigaben: Hinweis-Kachel,
   Personen mit Umschalter in einer Listen-Kachel, erhaltene Freigaben als
   zweite. Saldo-artige Werte nur negativ in Ausgabenfarbe. Vorschau:
   `#/more/planning`, `#/more/cashflow`, `#/more/settle`,
   `#/more/reminders`, `#/more/sharing` (Beispiel-Daueraufträge und
   -Freigaben; Erinnerungen werden jetzt echt aus den Beispieldaten berechnet).
   Sichtprüfung nachgeholt (2026-11-16, schmal und breit, alle drei
   Paletten): behoben wurden abgeschnittene Überschriften in Summen-Kacheln
   (`BentoStat` jetzt bis zwei Zeilen, das Raster gleicht die Höhen an),
   „Hochrechnung Monatsende" neben der Marke und der Fixkosten-Rhythmus
   (zwei Zeilen); der Hinweis unter „Abrechnen" ist breit auf 640 px
   begrenzt. `pdf_export.dart` behält feste Farben (Papier, kein UI).
2. Phase 4 (Rest) – Wasm erst nach Update/Ersatz von `ua_client_hints`
   erneut prüfen; Startzeit mit echten Daten messen.
3. Phase 5 – erledigt (2026-11-16), siehe Abschnitt „Abschlussprüfung".
4. Rest: Startzeit mit echten Daten messen; Sichtprüfung mit Login auf
   Windows und Android; danach PR nach `main`.

Kein PR nach `main` und kein Merge ohne ausdrückliche Freigabe des Nutzers.

## Abschlussprüfung (Phase 5, 2026-11-16)

Mit `impeccable audit` als Leitfaden. Der DOM-Detektor greift bei Flutter
(CanvasKit malt auf ein Canvas) nicht; geprüft wurde am Code, mit Tests und
im Bild (Design-Vorschau, Chromium, schmal/breit, drei Paletten).

| Bereich | Ergebnis |
|---|---|
| Kontrast | Paletten-Test deckt Text auf Kachel/Hintergrund, Signalfarben, Akzent ab (alle > 4,5:1). Glas bei „Kontrast erhöhen" deckend. Kein Befund im Bild. |
| Fokus/Tastatur | **Behoben:** Fokus war ein 12-%-Grauschleier, auf hellen Kacheln kaum sichtbar. Jetzt Akzentfarbe 20 % (`focusColor` im Theme), auf dem Plus-Knopf helle Tönung. Tab-Reihenfolge folgt dem Layout. |
| Reduzierte Bewegung | `PressScale` war schon abgesichert. **Behoben:** Seitenwechsel zoomten/schoben auch bei „Bewegung reduzieren"; jetzt nur Überblenden. Test dazu. |
| Abstände/Einheitlichkeit | Kacheln einheitlich (Radius 22, Haarlinie, Abstand `Bento.gap` 12). Die fünf verbliebenen `Card`s nutzen das gleiche Card-Theme. **Behoben:** nackte Icons in Abos, Wechselkursen und Reservierungs-Summe jetzt im `BentoGlyph`-Kreis wie überall. |
| Feste Farben | Keine außerhalb von `theme.dart`, `pdf_export.dart` und Vorschau. |
| Touch-Ziele | Listenzeilen, Tableiste und Plus-Knopf ≥ 44 px. |

Optimierungs-Checkliste: Das Redesign ändert die Datenschicht nicht (nur
Paletten-Einstellung). N+1, Indizes, nur Benötigtes laden, Bündeln/Entprellen,
Cache mit Invalidierung und Optimistic Updates wurden in PR #6 geprüft und
gelten unverändert. Neu: Beleg-Vorschau dekodiert nur noch in Fensterbreite
(`cacheWidth`). Glas-Unschärfe nur auf der Bedienebene (eine
`BackdropFilter`-Stelle). Der Verlaufs-Painter der Schulden zeichnet nicht
mehr bei jedem Frame (Teil 8). Lange Listen (Buchungen, Kategorien, Konten)
bauen zeilenweise; kurze Kachel-Listen (Cashflow 60 Tage, Abos) bewusst nicht.

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

- Freigaben: Umschalten wartet zu Recht auf den Server (Zugriffsrechte),
  zeigt bei einem Fehler aber keine Meldung (vor dem Redesign so; nicht
  Teil dieses Umbaus).
- Fokus-Ring nur in Chromium per Tab geprüft, nicht mit Windows-Tastatur
  in der nativen App.

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
