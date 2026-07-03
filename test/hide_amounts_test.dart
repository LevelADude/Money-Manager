// Verifiziert das Feature „Beträge verbergen" (Quick-Toggle + MoneyText)
// als Widget-Test — Ersatz für den Live-Browser-Test, der ohne Login gegen
// die Produktiv-DB nicht möglich ist.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:money_manager/data/local/app_cache.dart';
import 'package:money_manager/l10n/app_localizations.dart';
import 'package:money_manager/shared/hide_amounts_toggle.dart';
import 'package:money_manager/shared/money_text.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<Widget> _app({required Widget child}) async {
  final prefs = await SharedPreferences.getInstance();
  return ProviderScope(
    overrides: [sharedPrefsProvider.overrideWithValue(prefs)],
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        appBar: AppBar(actions: const [HideAmountsToggle()]),
        body: const Center(child: MoneyText(123456)),
      ),
    ),
  );
}

void main() {
  testWidgets('MoneyText zeigt Betrag, wenn Verbergen aus ist', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(await _app(child: const SizedBox()));
    await tester.pumpAndSettle();

    // 1234,56 € im de_DE-Format (genaue Formatierung prüft money_test.dart).
    expect(find.textContaining('1.234,56'), findsOneWidget);
    expect(find.text('****'), findsNothing);
  });

  testWidgets('MoneyText zeigt **** bei gespeicherter Einstellung', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({'settings_hide_amounts': true});
    await tester.pumpWidget(await _app(child: const SizedBox()));
    await tester.pumpAndSettle();

    expect(find.text('****'), findsOneWidget);
    expect(find.textContaining('1.234,56'), findsNothing);
  });

  testWidgets('Toggle blendet Beträge aus und wieder ein', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(await _app(child: const SizedBox()));
    await tester.pumpAndSettle();

    expect(find.text('****'), findsNothing);
    expect(find.byIcon(Icons.visibility_outlined), findsOneWidget);

    await tester.tap(find.byType(HideAmountsToggle));
    await tester.pumpAndSettle();
    expect(find.text('****'), findsOneWidget);
    expect(find.byIcon(Icons.visibility_off_outlined), findsOneWidget);

    // Einstellung landet in SharedPreferences (überlebt Neustart).
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool('settings_hide_amounts'), isTrue);

    await tester.tap(find.byType(HideAmountsToggle));
    await tester.pumpAndSettle();
    expect(find.text('****'), findsNothing);
    expect(prefs.getBool('settings_hide_amounts'), isFalse);
  });
}
