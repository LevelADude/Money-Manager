// Glas-Sheet: öffnet über dem Root-Navigator als dicke Glasfläche mit Griff,
// liefert das Ergebnis zurück und wird bei „Kontrast erhöhen" deckend.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:money_manager/core/theme.dart';
import 'package:money_manager/shared/glass.dart';

Widget _app(AppPalette palette, {bool highContrast = false}) => MaterialApp(
  theme: AppTheme.themeFor(palette),
  builder: (context, child) => MediaQuery(
    data: MediaQuery.of(context).copyWith(highContrast: highContrast),
    child: child!,
  ),
  home: Scaffold(
    body: Builder(
      builder: (context) => Center(
        child: FilledButton(
          onPressed: () async {
            final r = await showGlassSheet<String>(
              context: context,
              builder: (ctx) => ListTile(
                title: const Text('Eintrag'),
                onTap: () => Navigator.pop(ctx, 'gewählt'),
              ),
            );
            if (context.mounted) {
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(SnackBar(content: Text('Ergebnis: $r')));
            }
          },
          child: const Text('Öffnen'),
        ),
      ),
    ),
  ),
);

void main() {
  for (final palette in [
    AppPalette.sage,
    AppPalette.emerald,
    AppPalette.dark,
  ]) {
    testWidgets('Sheet ${palette.name}: Glas, Griff, Ergebnis', (tester) async {
      await tester.pumpWidget(_app(palette));
      expect(find.byType(BackdropFilter), findsNothing);
      await tester.tap(find.text('Öffnen'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      final glass = tester.widget<Glass>(find.byType(Glass));
      expect(glass.thick, isTrue);
      expect(find.byType(BackdropFilter), findsOneWidget);
      // Das Material-Sheet selbst malt keine Fläche mehr.
      final sheet = tester.widget<BottomSheet>(find.byType(BottomSheet));
      expect(sheet.backgroundColor, Colors.transparent);
      expect(sheet.showDragHandle, isFalse);

      await tester.tap(find.text('Eintrag'));
      await tester.pumpAndSettle();
      expect(find.byType(Glass), findsNothing);
      expect(find.text('Ergebnis: gewählt'), findsOneWidget);
    });
  }

  testWidgets('Sheet bei „Kontrast erhöhen": deckend, ohne Unschärfe', (
    tester,
  ) async {
    await tester.pumpWidget(_app(AppPalette.sage, highContrast: true));
    await tester.tap(find.text('Öffnen'));
    await tester.pumpAndSettle();
    expect(find.byType(Glass), findsOneWidget);
    expect(find.byType(BackdropFilter), findsNothing);
  });
}
