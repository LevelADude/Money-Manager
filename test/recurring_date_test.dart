import 'package:flutter_test/flutter_test.dart';
import 'package:money_manager/data/models/recurring_rule.dart';

void main() {
  group('advanceDate', () {
    test('Tage', () {
      expect(
        advanceDate(DateTime(2026, 1, 15), IntervalUnit.day, 10),
        DateTime(2026, 1, 25),
      );
    });

    test('Wochen', () {
      expect(
        advanceDate(DateTime(2026, 1, 1), IntervalUnit.week, 2),
        DateTime(2026, 1, 15),
      );
    });

    test('Monat: normaler Tag bleibt gleich', () {
      expect(
        advanceDate(DateTime(2026, 1, 15), IntervalUnit.month, 1),
        DateTime(2026, 2, 15),
      );
    });

    test('Monat: 31. klemmt auf Februar-Ende', () {
      expect(
        advanceDate(DateTime(2026, 1, 31), IntervalUnit.month, 1),
        DateTime(2026, 2, 28),
      );
    });

    test('Monat: Schaltjahr-Februar', () {
      expect(
        advanceDate(DateTime(2024, 1, 31), IntervalUnit.month, 1),
        DateTime(2024, 2, 29),
      );
    });

    test('Monatsende-Regel driftet NICHT nach unten (28.02 -> 31.03)', () {
      // Eine "letzter Tag des Monats"-Regel muss nach Februar wieder auf den
      // letzten Tag springen, nicht auf dem 28. hängenbleiben.
      expect(
        advanceDate(DateTime(2026, 2, 28), IntervalUnit.month, 1),
        DateTime(2026, 3, 31),
      );
    });

    test('Monat: Jahreswechsel', () {
      expect(
        advanceDate(DateTime(2026, 12, 15), IntervalUnit.month, 1),
        DateTime(2027, 1, 15),
      );
    });

    test('Jahr: 12 Monate weiter', () {
      expect(
        advanceDate(DateTime(2026, 3, 10), IntervalUnit.year, 1),
        DateTime(2027, 3, 10),
      );
    });
  });
}
