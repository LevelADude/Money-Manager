import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:money_manager/data/models/app_transaction.dart'
    show TransactionType;
import 'package:money_manager/data/models/category.dart';
import 'package:money_manager/data/models/category_pref.dart';
import 'package:money_manager/features/currency/fx_service.dart';
import 'package:money_manager/shared/category_icons.dart';
import 'package:money_manager/shared/money.dart';
import 'package:money_manager/shared/world_currencies.dart';

Category _cat({
  String? emoji,
  String? icon = 'cart',
  bool active = true,
  int sortOrder = 0,
}) => Category(
  id: 'c1',
  name: 'Test',
  kind: CategoryKind.expense,
  parentId: null,
  icon: icon,
  color: null,
  isPreset: false,
  active: active,
  emoji: emoji,
  sortOrder: sortOrder,
);

void main() {
  group('Weltwährungen (Symbol/Decimals)', () {
    test('bekannte Symbole', () {
      expect(currencySymbol('USD'), r'$');
      expect(currencySymbol('EUR'), '€');
      expect(currencySymbol('GBP'), '£');
      expect(currencySymbol('JPY'), '¥');
    });
    test('unbekannter Code fällt auf den Code zurück', () {
      expect(currencySymbol('BTC'), 'BTC');
      expect(currencyDecimals('BTC'), 2);
    });
    test('Nachkommastellen je Währung', () {
      expect(currencyDecimals('JPY'), 0); // ohne Nachkomma
      expect(currencyDecimals('KWD'), 3); // 3 Nachkommastellen
      expect(currencyDecimals('EUR'), 2);
    });
    test('Liste ist groß und eindeutig', () {
      expect(worldCurrencies.length, greaterThan(150));
      final codes = worldCurrencies.map((c) => c.code).toSet();
      expect(codes.length, worldCurrencies.length); // keine Duplikate
      expect(worldCurrencyByCode['USD']!.name, 'US Dollar');
    });
  });

  group('evalExpression – beliebige Währungssymbole', () {
    test('Dollar-Zeichen wird ignoriert', () {
      expect(evalExpression(r'12,50 $ + 3'), 15.5);
    });
    test('Pfund-Zeichen wird ignoriert', () {
      expect(evalExpression('10 £'), 10);
    });
    test('Buchstabe bleibt ungültig', () {
      expect(evalExpression('12a'), isNull);
    });
  });

  group('FxRates (JSON + Kursrichtung)', () {
    test('fromJson/toJson Round-Trip', () {
      final r = FxRates(
        base: 'EUR',
        ratesToBase: {'USD': 0.92, 'CHF': 1.05},
        fetchedAtMs: 123456,
      );
      final back = FxRates.fromJson(r.toJson());
      expect(back.base, 'EUR');
      expect(back.ratesToBase['USD'], 0.92);
      expect(back.fetchedAtMs, 123456);
    });
  });

  group('Category – Emoji & Overlay', () {
    test('copyWith überschreibt aktiv/Reihenfolge, behält Emoji', () {
      final c = _cat(emoji: '🍔', active: true, sortOrder: 0);
      final o = c.copyWith(active: false, sortOrder: 5);
      expect(o.active, false);
      expect(o.sortOrder, 5);
      expect(o.emoji, '🍔'); // bleibt erhalten
      expect(o.name, 'Test');
    });
    test('copyWith ohne Argumente ändert nichts', () {
      final c = _cat(active: true, sortOrder: 3);
      final o = c.copyWith();
      expect(o.active, true);
      expect(o.sortOrder, 3);
    });
    test('matches richtet sich nach der Art', () {
      final c = _cat();
      expect(c.matches(TransactionType.expense), true);
      expect(c.matches(TransactionType.income), false);
    });
  });

  group('CategoryPref.fromJson', () {
    test('vollständige Zeile', () {
      final p = CategoryPref.fromJson({
        'category_id': 'c1',
        'active': false,
        'sort_order': 7,
        'hidden': true,
      });
      expect(p.categoryId, 'c1');
      expect(p.active, false);
      expect(p.sortOrder, 7);
      expect(p.hidden, true);
    });
    test('fehlende Felder erben (null) bzw. default hidden=false', () {
      final p = CategoryPref.fromJson({'category_id': 'c2'});
      expect(p.active, isNull);
      expect(p.sortOrder, isNull);
      expect(p.hidden, false);
    });
  });

  group('categoryGlyph (Emoji vs. Icon)', () {
    testWidgets('zeigt Emoji, wenn gesetzt', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: categoryGlyph(_cat(emoji: '🍔'))),
        ),
      );
      expect(find.text('🍔'), findsOneWidget);
      expect(find.byIcon(Icons.shopping_cart_outlined), findsNothing);
    });
    testWidgets('zeigt Icon, wenn kein Emoji', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: categoryGlyph(_cat(icon: 'cart'))),
        ),
      );
      expect(find.byIcon(Icons.shopping_cart_outlined), findsOneWidget);
    });
    testWidgets('leeres Emoji zählt als „kein Emoji"', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: categoryGlyph(_cat(emoji: '  ', icon: 'cart')),
          ),
        ),
      );
      expect(find.byIcon(Icons.shopping_cart_outlined), findsOneWidget);
    });
  });
}
