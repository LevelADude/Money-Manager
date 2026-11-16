// Theme und Glas-Navigation: bauen in jeder Palette und in beiden Breiten
// ohne Layout- oder Laufzeitfehler, und die Bedienelemente reagieren.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:money_manager/core/main_scaffold.dart';
import 'package:money_manager/core/theme.dart';
import 'package:money_manager/shared/glass.dart';

const _items = [
  (icon: Icons.wallet_outlined, active: Icons.wallet, label: 'Konten'),
  (
    icon: Icons.receipt_long_outlined,
    active: Icons.receipt_long,
    label: 'Buchungen',
  ),
  (icon: Icons.bar_chart_outlined, active: Icons.bar_chart, label: 'Statistik'),
  (icon: Icons.menu, active: Icons.menu, label: 'Mehr'),
];

void main() {
  for (final palette in AppPalette.values) {
    test('Palette ${palette.name}: Farben vollständig und lesbar', () {
      final theme = AppTheme.themeFor(palette);
      final c = theme.extension<AppColors>();
      expect(c, isNotNull);
      // Seiten malen ihren Hintergrund selbst.
      expect(theme.scaffoldBackgroundColor, Colors.transparent);

      double contrast(Color a, Color b) {
        final la = a.computeLuminance(), lb = b.computeLuminance();
        final hi = la > lb ? la : lb, lo = la > lb ? lb : la;
        return (hi + .05) / (lo + .05);
      }

      final s = theme.colorScheme;
      // WCAG AA für Fließtext auf Kachel und Grundfläche, Schrift auf Akzent.
      expect(contrast(s.onSurface, c!.card), greaterThan(4.5));
      expect(contrast(s.onSurface, c.background), greaterThan(4.5));
      expect(contrast(s.onSurfaceVariant, c.card), greaterThan(4.5));
      expect(contrast(s.onSurfaceVariant, c.background), greaterThan(4.5));
      expect(contrast(s.onPrimary, s.primary), greaterThan(4.5));
      expect(contrast(c.income, c.card), greaterThan(4.5));
      expect(contrast(c.expense, c.card), greaterThan(4.5));
      expect(contrast(c.warning, c.card), greaterThan(4.5));
      expect(contrast(s.primary, s.primaryContainer), greaterThan(4.5));
    });
  }

  testWidgets('Tableiste und Plus-Knopf: schmal, tippen wählt aus', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 812);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    var selected = 1, added = 0;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.themeFor(AppPalette.emerald),
        home: StatefulBuilder(
          builder: (context, setState) => Scaffold(
            body: const SizedBox.expand(),
            bottomNavigationBar: SafeArea(
              minimum: const EdgeInsets.fromLTRB(14, 8, 14, 14),
              child: Row(
                children: [
                  Expanded(
                    child: GlassTabBar(
                      items: _items,
                      current: selected,
                      onSelect: (i) => setState(() => selected = i),
                    ),
                  ),
                  const SizedBox(width: 12),
                  GlassAddButton(onTap: () => added++, label: 'Buchung'),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    expect(tester.takeException(), isNull);
    expect(find.byType(AppBackdrop), findsOneWidget);
    for (final it in _items) {
      expect(find.text(it.label), findsOneWidget);
    }

    await tester.tap(find.text('Statistik'));
    await tester.pumpAndSettle();
    expect(selected, 2);

    await tester.tap(find.byIcon(Icons.add));
    await tester.pumpAndSettle();
    expect(added, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Seitenleiste: niedriges Fenster läuft nicht über', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 420);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.themeFor(AppPalette.dark),
        home: Scaffold(
          body: Row(
            children: [
              Padding(
                padding: const EdgeInsets.all(14),
                child: GlassRail(
                  items: _items,
                  current: 0,
                  onSelect: (_) {},
                  onAdd: () {},
                  addLabel: 'Buchung',
                ),
              ),
              const Expanded(child: SizedBox.expand()),
            ],
          ),
        ),
      ),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('Glas wird bei „Kontrast erhöhen" deckend', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.themeFor(AppPalette.sage),
        home: const MediaQuery(
          data: MediaQueryData(highContrast: true),
          child: Center(child: Glass(child: SizedBox(width: 80, height: 40))),
        ),
      ),
    );
    expect(find.byType(BackdropFilter), findsNothing);
  });

  testWidgets('Seitenwechsel blendet bei „Bewegung reduzieren" nur über', (
    tester,
  ) async {
    // Auf iOS schiebt der normale Übergang die Seite (SlideTransition).
    Future<bool> slidesDuringPush({required bool reduce}) async {
      await tester.pumpWidget(
        MediaQuery(
          data: MediaQueryData(disableAnimations: reduce),
          child: MaterialApp(
            key: UniqueKey(),
            theme: AppTheme.themeFor(
              AppPalette.sage,
            ).copyWith(platform: TargetPlatform.iOS),
            home: Builder(
              builder: (context) => TextButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(builder: (_) => const Text('Ziel')),
                ),
                child: const Text('Los'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Los'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      final slides = find
          .ancestor(
            of: find.text('Ziel'),
            matching: find.byType(SlideTransition),
          )
          .evaluate()
          .isNotEmpty;
      await tester.pumpAndSettle();
      expect(find.text('Ziel'), findsOneWidget);
      return slides;
    }

    expect(await slidesDuringPush(reduce: false), isTrue);
    expect(await slidesDuringPush(reduce: true), isFalse);
  });

  test('Fokusfarbe ist die Akzentfarbe, nicht das blasse Standardgrau', () {
    for (final p in AppPalette.values) {
      final t = AppTheme.themeFor(p);
      expect(t.focusColor, t.colorScheme.primary.withValues(alpha: .2));
    }
  });
}
