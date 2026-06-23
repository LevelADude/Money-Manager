import 'package:flutter_test/flutter_test.dart';
import 'package:money_manager/shared/money.dart';

void main() {
  group('evalExpression', () {
    test('einfache Zahl mit Komma', () {
      expect(evalExpression('12,50'), 12.5);
    });
    test('Addition mit Komma', () {
      expect(evalExpression('12,50+3'), 15.5);
    });
    test('Punkt-vor-Strich', () {
      expect(evalExpression('2+3*4'), 14);
    });
    test('Klammern', () {
      expect(evalExpression('(1+2)*4'), 12);
    });
    test('Division', () {
      expect(evalExpression('10/4'), 2.5);
    });
    test('unäres Minus', () {
      expect(evalExpression('-5+2'), -3);
    });
    test('Division durch Null ist ungültig', () {
      expect(evalExpression('1/0'), isNull);
    });
    test('leere Eingabe', () {
      expect(evalExpression(''), isNull);
    });
    test('unerlaubtes Zeichen', () {
      expect(evalExpression('12a'), isNull);
    });
    test('Euro-Zeichen + Leerzeichen werden ignoriert', () {
      expect(evalExpression('12,50 € + 3 €'), 15.5);
    });
  });

  group('parseToCents', () {
    test('Komma-Betrag', () {
      expect(parseToCents('12,50'), 1250);
    });
    test('Ganzzahl', () {
      expect(parseToCents('5'), 500);
    });
    test('Rechenausdruck', () {
      expect(parseToCents('10+2,50'), 1250);
    });
    test('Müll ergibt null', () {
      expect(parseToCents('abc'), isNull);
    });
    test('Rundung', () {
      expect(parseToCents('0,005'), 1); // 0.5 Cent -> 1 (round)
    });
  });

  group('centsToInput', () {
    test('positiv', () => expect(centsToInput(1250), '12,50'));
    test('null', () => expect(centsToInput(0), '0,00'));
    test('negativ', () => expect(centsToInput(-500), '-5,00'));
  });

  group('formatCents', () {
    test('enthält Betrag und Euro', () {
      final s = formatCents(1250);
      expect(s.contains('12,50'), isTrue);
      expect(s.contains('€'), isTrue);
    });
    test('negativer Betrag', () {
      expect(formatCents(-100).contains('1,00'), isTrue);
    });
  });

  group('formatMoney Nachkommastellen je Währung', () {
    test('JPY ohne Nachkommastellen', () {
      final s = formatMoney(100000, 'JPY'); // 1000 Yen
      expect(s.contains('¥'), isTrue);
      expect(s.contains('1.000'), isTrue);
      expect(s.contains(','), isFalse);
    });
    test('EUR mit zwei Nachkommastellen', () {
      expect(formatMoney(1250, 'EUR').contains('12,50'), isTrue);
    });
    test('currencyDecimals', () {
      expect(currencyDecimals('JPY'), 0);
      expect(currencyDecimals('EUR'), 2);
      expect(currencyDecimals('XYZ'), 2);
    });
  });
}
