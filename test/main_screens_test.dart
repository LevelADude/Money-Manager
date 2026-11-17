// Die vier Hauptscreens (Konten, Buchungen, Statistik, Mehr) mit
// Beispieldaten: bauen in jeder Palette, schmal und breit, ohne Layout- oder
// Laufzeitfehler, zeigen ihre Kacheln und nutzen Glas nur in der Navigation.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:money_manager/core/main_scaffold.dart';
import 'package:money_manager/core/theme.dart';
import 'package:money_manager/dev_preview.dart';
import 'package:money_manager/dev_preview_data.dart';
import 'package:money_manager/features/transactions/person_filter.dart';
import 'package:money_manager/features/transactions/transaction_form_screen.dart';
import 'package:money_manager/shared/bento.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _sizes = {'schmal': Size(390, 844), 'breit': Size(1280, 800)};
const _palettes = [AppPalette.sage, AppPalette.emerald, AppPalette.dark];

Future<void> _pump(
  WidgetTester tester,
  String route,
  AppPalette palette,
  Size size, {
  bool allPersons = false,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        ...previewOverrides(prefs, now: DateTime(2026, 11, 15)),
        if (!allPersons) personFilterProvider.overrideWith(_FixedPerson.new),
      ],
      child: PreviewApp(initialLocation: route, palette: palette),
    ),
  );
  await tester.pumpAndSettle();
}

class _FixedPerson extends PersonFilterNotifier {
  @override
  String? build() => previewUserId;
}

/// Glas (Unschärfe) darf nur in der Navigation liegen, nie im Inhalt.
void _expectGlassOnlyInNavigation() {
  final blurs = find.byType(BackdropFilter);
  for (final e in blurs.evaluate()) {
    final inNav =
        find
            .ancestor(
              of: find.byWidget(e.widget),
              matching: find.byType(GlassRail),
            )
            .evaluate()
            .isNotEmpty ||
        find
            .ancestor(
              of: find.byWidget(e.widget),
              matching: find.byType(GlassTabBar),
            )
            .evaluate()
            .isNotEmpty ||
        find
            .ancestor(
              of: find.byWidget(e.widget),
              matching: find.byType(GlassAddButton),
            )
            .evaluate()
            .isNotEmpty;
    expect(inNav, isTrue, reason: 'BackdropFilter außerhalb der Navigation');
  }
}

void main() {
  setUpAll(() => initializeDateFormatting('de', null));

  for (final palette in _palettes) {
    for (final size in _sizes.entries) {
      final tag = '${palette.name}, ${size.key}';

      testWidgets('Konten ($tag): Gesamtsaldo, Summen, Konten-Kacheln', (
        tester,
      ) async {
        await _pump(tester, '/', palette, size.value, allPersons: true);
        expect(tester.takeException(), isNull);
        expect(find.text('Gesamtvermögen'), findsOneWidget);
        expect(find.text('Vermögen je Person'), findsOneWidget);
        expect(find.text('Meine Summen'), findsOneWidget);
        expect(find.text('Girokonto'), findsOneWidget);
        expect(find.byType(BentoList), findsWidgets);
        expect(find.byType(Card), findsNothing);
        _expectGlassOnlyInNavigation();
      });

      testWidgets('Buchungen ($tag): Summen-Kacheln und Tageslisten', (
        tester,
      ) async {
        await _pump(tester, '/transactions', palette, size.value);
        expect(tester.takeException(), isNull);
        expect(find.byType(BentoStat), findsNWidgets(3));
        expect(find.text('Einnahmen'), findsOneWidget);
        expect(find.text('Ausgaben'), findsOneWidget);
        expect(find.text('Saldo'), findsOneWidget);
        expect(find.text('REWE City'), findsOneWidget);
        // Kategorie-Emoji im getönten Kreis.
        expect(
          find.descendant(
            of: find.byType(BentoGlyph),
            matching: find.text('🛒'),
          ),
          findsWidgets,
        );
        expect(find.byType(Card), findsNothing);
        _expectGlassOnlyInNavigation();
      });

      testWidgets('Statistik ($tag): Kennzahlen und Diagramme in Kacheln', (
        tester,
      ) async {
        await _pump(tester, '/statistics', palette, size.value);
        expect(tester.takeException(), isNull);
        expect(find.byType(BentoStat), findsNWidgets(5));
        expect(find.text('Saldo im Zeitraum'), findsOneWidget);
        expect(find.byType(Card), findsNothing);
        // Bis ans Ende scrollen: jede Kachel wird einmal gebaut.
        await tester.drag(find.byType(ListView).first, const Offset(0, -5000));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        _expectGlassOnlyInNavigation();
      });

      testWidgets('Mehr ($tag): Einträge als gruppierte Kacheln', (
        tester,
      ) async {
        await _pump(tester, '/more', palette, size.value);
        expect(tester.takeException(), isNull);
        expect(find.byType(BentoList), findsNWidgets(6));
        expect(find.text('Einstellungen'), findsOneWidget);
        expect(find.byType(ListTile), findsNothing);
        _expectGlassOnlyInNavigation();
      });
    }
  }

  testWidgets('Buchungen: Suche filtert, Zeile öffnet die Buchung', (
    tester,
  ) async {
    await _pump(tester, '/transactions', AppPalette.sage, _sizes['schmal']!);
    await tester.enterText(find.byType(TextField), 'rewe');
    await tester.pumpAndSettle();
    expect(find.text('REWE City'), findsOneWidget);
    expect(find.text('Deutschlandticket'), findsNothing);
    await tester.tap(find.text('REWE City'));
    await tester.pumpAndSettle();
    expect(find.byType(TransactionFormScreen), findsOneWidget);
  });

  testWidgets('Buchungen breit: Kategorie und Konto als eigene Spalten', (
    tester,
  ) async {
    await _pump(tester, '/transactions', AppPalette.sage, _sizes['breit']!);
    final title = tester.getRect(find.text('REWE City'));
    final category = tester.getRect(find.text('Lebensmittel').first);
    expect(category.left, greaterThan(title.right));
    expect((category.center.dy - title.center.dy).abs(), lessThan(12));
  });

  testWidgets('Mehr: Tippen auf einen Eintrag navigiert', (tester) async {
    await _pump(tester, '/more', AppPalette.dark, _sizes['schmal']!);
    await tester.tap(find.text('Budgets'));
    await tester.pumpAndSettle();
    // Budgets ist Teil der Vorschau: die echte Seite statt des Platzhalters.
    expect(find.text('Gesamtbudget · Dieser Monat'), findsOneWidget);
  });

  testWidgets('Export: Aktionen als Listen-Kachel, CSV-Vorschau als Kachel', (
    tester,
  ) async {
    await _pump(tester, '/more/export', AppPalette.sage, _sizes['schmal']!);
    expect(find.byType(BentoList), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(BentoList),
        matching: find.byType(BentoRow),
      ),
      findsAtLeastNWidgets(3),
    );
    // Kopfzeile der CSV steht in der Vorschau-Kachel.
    expect(
      find.descendant(
        of: find.byType(BentoTile),
        matching: find.textContaining('Datum;Typ;Betrag'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('Import: falscher Kopf meldet den Status in einer Kachel', (
    tester,
  ) async {
    await _pump(tester, '/more/import', AppPalette.sage, _sizes['schmal']!);
    final tiles = find.byType(BentoTile).evaluate().length;
    await tester.enterText(find.byType(TextField), 'foo;bar\n1;2');
    await tester.tap(find.byType(FilledButton));
    await tester.pumpAndSettle();
    expect(find.byType(BentoTile).evaluate().length, tiles + 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Insights: Abschnitte als Listen-Kacheln, Umschalter wirkt', (
    tester,
  ) async {
    await _pump(tester, '/more/insights', AppPalette.sage, _sizes['schmal']!);
    expect(find.byType(BentoList), findsAtLeastNWidgets(1));
    expect(find.byType(BentoSectionHeader), findsAtLeastNWidgets(1));
    await tester.tap(find.text('Dieses Jahr'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.byType(BentoList), findsAtLeastNWidgets(1));
  });

  testWidgets('Simulator: Eingaben ändern Überschuss und Vermögens-Kachel', (
    tester,
  ) async {
    await _pump(tester, '/more/simulator', AppPalette.dark, _sizes['schmal']!);
    final fields = find.byType(TextField);
    // Vorbelegt mit den Monatsdurchschnitten, sobald Buchungen da sind.
    final prefilled = tester.widget<TextField>(fields.at(0)).controller!.text;
    expect(prefilled, isNot(anyOf('', '0,00')));
    await tester.enterText(fields.at(0), '1000');
    await tester.enterText(fields.at(1), '400');
    await tester.pumpAndSettle();
    // Überschuss als Summen-Kachel, Veränderung in 12 Monaten als Marke.
    expect(
      find.descendant(
        of: find.byType(BentoStat),
        matching: find.textContaining('600,00'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byType(BentoChip),
        matching: find.textContaining('7.200,00'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('Archiv-Einrichtung: Status in der Hinweis-Kachel', (
    tester,
  ) async {
    await _pump(
      tester,
      '/more/archive/setup',
      AppPalette.emerald,
      _sizes['schmal']!,
    );
    expect(
      find.descendant(
        of: find.byType(BentoTile),
        matching: find.textContaining('beispiel/archiv'),
      ),
      findsOneWidget,
    );
    expect(find.byType(LinearProgressIndicator), findsNothing);
  });

  testWidgets('Budgets: Gesamtbudget, Verplant und zwei Listen-Kacheln', (
    tester,
  ) async {
    await _pump(tester, '/more/budgets', AppPalette.sage, _sizes['schmal']!);
    // Ausgaben 1.–15.11. gegen 2.000 € Gesamtbudget.
    expect(find.textContaining('935,96'), findsWidgets);
    expect(find.text('47 %'), findsOneWidget);
    expect(find.textContaining('900,00'), findsOneWidget); // frei verteilbar
    // Gesamt + Verplant + vier Kategorie-Budgets.
    expect(find.byType(BentoProgress), findsNWidgets(6));
    // Mit Budget und ohne Budget je eine Kachel.
    expect(find.byType(BentoList), findsNWidgets(2));
    expect(find.textContaining('8,00'), findsWidgets); // Mobilität überzogen
    expect(find.text('Budget setzen'), findsNWidgets(2));
  });

  testWidgets('Sparziele: Kacheln mit Balken, erreichtes Ziel ohne Knopf', (
    tester,
  ) async {
    await _pump(tester, '/more/goals', AppPalette.dark, _sizes['breit']!);
    expect(find.text('Urlaub Portugal'), findsOneWidget);
    expect(find.text('Ziel erreicht! 🎉'), findsOneWidget);
    // Der offene Topf hat keinen Balken, das erreichte Ziel keinen Knopf.
    expect(find.byType(BentoProgress), findsNWidgets(2));
    expect(find.text('Einzahlen'), findsNWidgets(2));
  });

  testWidgets('Schulden: Summe, Auslastung und Verlauf je Konto', (
    tester,
  ) async {
    await _pump(tester, '/more/debts', AppPalette.emerald, _sizes['schmal']!);
    expect(
      find.descendant(
        of: find.byType(BentoStat),
        matching: find.textContaining('344,00'),
      ),
      findsOneWidget,
    );
    expect(find.text('23 %'), findsOneWidget); // 344 von 1.500 €
    expect(find.byType(BentoProgress), findsOneWidget);
  });

  testWidgets('Planung: Verfügbar und Hochrechnung als Kacheln, Fixkosten', (
    tester,
  ) async {
    await _pump(tester, '/more/planning', AppPalette.sage, _sizes['schmal']!);
    expect(tester.takeException(), isNull);
    expect(find.text('Verfügbar bis Monatsende'), findsOneWidget);
    expect(find.byType(BentoGrid), findsOneWidget);
    // Vier Fixkosten (Gehalt ist Einnahme) in einer Listen-Kachel.
    expect(find.byType(BentoList), findsOneWidget);
    expect(find.text('Handyvertrag'), findsOneWidget);
    expect(find.text('Gehalt'), findsNothing);
    expect(find.byType(Card), findsNothing);
  });

  testWidgets('Cashflow: Saldo und Tiefststand, Ereignisse als Liste', (
    tester,
  ) async {
    await _pump(tester, '/more/cashflow', AppPalette.dark, _sizes['breit']!);
    expect(tester.takeException(), isNull);
    expect(find.byType(BentoStat), findsNWidgets(2));
    expect(find.text('Tiefststand (60 Tage)'), findsOneWidget);
    expect(find.byType(BentoList), findsOneWidget);
    expect(find.text('Fitnessstudio'), findsNWidgets(2)); // monatlich
    expect(find.byType(Card), findsNothing);
  });

  testWidgets('Abrechnen: Summen, Salden und Ausgleich', (tester) async {
    await _pump(tester, '/more/settle', AppPalette.emerald, _sizes['schmal']!);
    expect(tester.takeException(), isNull);
    expect(find.byType(BentoStat), findsNWidgets(2));
    expect(find.text('Salden je Person'), findsOneWidget);
    // Sam hat nichts ausgegeben und gleicht an Alex aus.
    expect(find.text('Sam → Alex'), findsOneWidget);
    expect(find.byType(BentoList), findsNWidgets(2));
    expect(find.byType(Card), findsNothing);
  });

  testWidgets('Erinnerungen: Streak-Kachel und Hinweise als Liste', (
    tester,
  ) async {
    await _pump(tester, '/more/reminders', AppPalette.sage, _sizes['schmal']!);
    expect(tester.takeException(), isNull);
    expect(find.text('🔥'), findsOneWidget);
    // Fällige Daueraufträge und Budget-Warnungen aus den Beispieldaten.
    expect(find.byType(BentoList), findsOneWidget);
    expect(find.byType(BentoRow), findsWidgets);
    expect(find.byType(Card), findsNothing);
  });

  testWidgets('Freigaben: Personen mit Umschalter, erhaltene als Liste', (
    tester,
  ) async {
    await _pump(tester, '/more/sharing', AppPalette.emerald, _sizes['breit']!);
    expect(tester.takeException(), isNull);
    expect(find.byType(SegmentedButton<String>), findsOneWidget);
    expect(find.text('Du darfst ansehen und verwalten'), findsOneWidget);
    expect(find.byType(BentoList), findsNWidgets(2));
    expect(find.byType(Card), findsNothing);
  });

  // Unterseiten aus Phase 3, die mit den Beispieldaten auskommen.
  for (final route in [
    '/account/giro',
    '/account/groups',
    '/more/search',
    '/more/projects',
    '/more/reservations',
    '/more/settings',
    '/more/archive',
    '/more/profile',
    '/more/export',
    '/more/import',
    '/more/insights',
    '/more/simulator',
    '/more/archive/setup',
    '/more/budgets',
    '/more/goals',
    '/more/debts',
    '/more/planning',
    '/more/cashflow',
    '/more/settle',
    '/more/reminders',
    '/more/sharing',
    '/account/new',
    '/more/recurring/new',
    '/more/reservations/new',
    '/transactions/new',
    '/transactions/tx0',
    '/login',
    '/reset-password',
    '/onboarding',
  ]) {
    for (final size in _sizes.entries) {
      testWidgets('Unterseite $route (${size.key}) baut ohne Fehler', (
        tester,
      ) async {
        await _pump(tester, route, AppPalette.emerald, size.value);
        expect(tester.takeException(), isNull);
        _expectGlassOnlyInNavigation();
      });
    }
  }
}
