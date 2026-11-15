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
    expect(find.textContaining('/transactions/tx0'), findsOneWidget);
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
    expect(find.textContaining('/more/budgets'), findsOneWidget);
  });
}
