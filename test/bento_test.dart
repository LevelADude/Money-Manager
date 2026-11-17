// Bento-Bausteine: Rasteraufteilung schmal/breit, deckende Kachel ohne
// Unschärfe, Zeilen reagieren auf Tippen.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:money_manager/core/theme.dart';
import 'package:money_manager/shared/bento.dart';

Widget _host(Widget child, {double width = 400}) => MaterialApp(
  theme: AppTheme.themeFor(AppPalette.sage),
  home: Scaffold(
    body: Align(
      alignment: Alignment.topLeft,
      child: SizedBox(width: width, child: child),
    ),
  ),
);

BentoGrid _grid() => BentoGrid(
  cells: [
    for (final k in ['a', 'b'])
      BentoCell(
        child: BentoStat(key: Key(k), label: k, value: const Text('1')),
      ),
    BentoCell(
      span: 2,
      child: BentoStat(
        key: const Key('c'),
        label: 'c',
        value: const Text('2'),
        sub: const Text('unten\nzwei Zeilen'),
      ),
    ),
  ],
);

void main() {
  testWidgets('Raster schmal: zwei Spalten, breite Zelle in eigener Zeile', (
    tester,
  ) async {
    await tester.pumpWidget(_host(_grid()));
    final a = tester.getRect(find.byKey(const Key('a')));
    final b = tester.getRect(find.byKey(const Key('b')));
    final c = tester.getRect(find.byKey(const Key('c')));
    expect(a.width, closeTo((400 - Bento.gap) / 2, .01));
    expect(b.left, closeTo(a.right + Bento.gap, .01));
    expect(a.top, b.top);
    expect(c.top, closeTo(a.bottom + Bento.gap, .01));
    expect(c.width, closeTo(400, .01));
    expect(tester.takeException(), isNull);
  });

  testWidgets('Raster breit: vier Spalten in einer Zeile, gleich hoch', (
    tester,
  ) async {
    await tester.pumpWidget(_host(_grid(), width: 800));
    final a = tester.getRect(find.byKey(const Key('a')));
    final c = tester.getRect(find.byKey(const Key('c')));
    final unit = (800 - 3 * Bento.gap) / 4;
    expect(a.width, closeTo(unit, .01));
    expect(c.top, a.top);
    expect(c.width, closeTo(2 * unit + Bento.gap, .01));
    expect(c.right, closeTo(800, .02));
    // Die höhere Kachel bestimmt die Zeilenhöhe.
    expect(a.height, c.height);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Spalten: schmal untereinander, breit nebeneinander', (
    tester,
  ) async {
    Widget cols() => const BentoColumns(
      left: [SizedBox(key: Key('l'), height: 40)],
      right: [SizedBox(key: Key('r'), height: 40)],
    );
    await tester.pumpWidget(_host(cols()));
    expect(tester.getTopLeft(find.byKey(const Key('r'))).dy, 40 + Bento.gap);
    await tester.pumpWidget(_host(cols(), width: 800));
    expect(tester.getTopLeft(find.byKey(const Key('r'))).dy, 0);
    expect(tester.getSize(find.byKey(const Key('l'))).width, 394);
  });

  for (final palette in [
    AppPalette.sage,
    AppPalette.emerald,
    AppPalette.dark,
  ]) {
    testWidgets('Kachel ${palette.name}: deckend in Kachelfarbe, kein Glas', (
      tester,
    ) async {
      var taps = 0;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.themeFor(palette),
          home: Scaffold(
            body: BentoList(
              children: [
                BentoRow(
                  leading: const BentoGlyph(child: Text('🛒')),
                  title: const Text('REWE City'),
                  subtitle: const Text('Lebensmittel'),
                  trailing: const Text('-42,18 €'),
                  onTap: () => taps++,
                ),
                const BentoRow(title: Text('Zweite Zeile')),
              ],
            ),
          ),
        ),
      );
      final colors = AppTheme.themeFor(palette).extension<AppColors>()!;
      final material = tester.widget<Material>(
        find
            .descendant(
              of: find.byType(BentoTile),
              matching: find.byType(Material),
            )
            .first,
      );
      expect(material.color, colors.card);
      expect(material.color!.a, 1);
      expect(find.byType(BackdropFilter), findsNothing);
      expect(find.byType(Divider), findsOneWidget);
      await tester.tap(find.text('REWE City'));
      expect(taps, 1);
      // Farbreihe für Diagramme: vollständig und ohne Dopplung.
      final series = AppColors.chartSeries(
        tester.element(find.byType(BentoList)),
      );
      expect(series.toSet().length, series.length);
    });
  }

  // Hover-/Druckfläche von Listenzeilen darf nicht bündig am Symbol enden:
  // Zeile mit Innenabstand, Kachel mit Luft ringsum, Text weiter 16 px vom
  // Kachelrand, Überschriften bündig mit dem Text.
  for (final (name, build) in [
    (
      'rowsPadding',
      () => BentoGroup(
        padding: BentoGroup.rowsPadding,
        children: [
          ListTile(
            key: const Key('row'),
            leading: const Icon(Icons.star, key: Key('icon')),
            title: const Text('Zeile'),
            onTap: () {},
          ),
        ],
      ),
    ),
    (
      'bentoSections',
      () => Column(
        children: bentoSections([
          const Text('Überschrift', key: Key('head')),
          SwitchListTile(
            key: const Key('row'),
            secondary: const Icon(Icons.star, key: Key('icon')),
            title: const Text('Zeile'),
            value: false,
            onChanged: (_) {},
          ),
        ]),
      ),
    ),
  ]) {
    testWidgets('Listenzeilen mit Abstand zur Hover-Fläche ($name)', (
      tester,
    ) async {
      await tester.pumpWidget(_host(build()));
      final tile = tester.getRect(find.byType(BentoTile));
      final row = tester.getRect(find.byKey(const Key('row')));
      final icon = tester.getRect(find.byKey(const Key('icon')));
      expect(row.left - tile.left, 6);
      expect(tile.right - row.right, 6);
      expect(icon.left - row.left, 10);
      if (name == 'bentoSections') {
        final head = tester.getRect(find.byKey(const Key('head')));
        expect(head.left - tile.left, 16);
      } else {
        expect(row.top - tile.top, 6);
      }
    });
  }
}
