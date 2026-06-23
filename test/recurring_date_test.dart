import 'package:flutter_test/flutter_test.dart';
import 'package:money_manager/data/models/recurring_rule.dart';

void main() {
  group('advanceDate – Tag/Woche', () {
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
  });

  group('advanceDate – Monat mit Anker-Tag', () {
    test('normaler Tag bleibt gleich', () {
      expect(
        advanceDate(
          DateTime(2026, 1, 15),
          IntervalUnit.month,
          1,
          anchorDay: 15,
        ),
        DateTime(2026, 2, 15),
      );
    });

    test('31.-Regel klemmt im Februar auf 28.', () {
      expect(
        advanceDate(
          DateTime(2026, 1, 31),
          IntervalUnit.month,
          1,
          anchorDay: 31,
        ),
        DateTime(2026, 2, 28),
      );
    });

    test('31.-Regel erholt sich nach dem Februar wieder auf 31.', () {
      // Vom (geklemmten) 28.02 weiter – dank Anker 31 zurück auf den 31.03.
      expect(
        advanceDate(
          DateTime(2026, 2, 28),
          IntervalUnit.month,
          1,
          anchorDay: 31,
        ),
        DateTime(2026, 3, 31),
      );
    });

    test('echte 28.-Regel bleibt 28. (keine Beförderung auf Monatsende)', () {
      // Regressionstest: 28.02 (Nicht-Schaltjahr) darf NICHT auf den 31.03 springen.
      expect(
        advanceDate(
          DateTime(2025, 2, 28),
          IntervalUnit.month,
          1,
          anchorDay: 28,
        ),
        DateTime(2025, 3, 28),
      );
    });

    test('30.-Regel bleibt 30. (auch nach einem 30-Tage-Monat)', () {
      expect(
        advanceDate(
          DateTime(2026, 4, 30),
          IntervalUnit.month,
          1,
          anchorDay: 30,
        ),
        DateTime(2026, 5, 30),
      );
    });

    test('Schaltjahr-Februar', () {
      expect(
        advanceDate(
          DateTime(2024, 1, 31),
          IntervalUnit.month,
          1,
          anchorDay: 31,
        ),
        DateTime(2024, 2, 29),
      );
    });

    test('Jahreswechsel', () {
      expect(
        advanceDate(
          DateTime(2026, 12, 15),
          IntervalUnit.month,
          1,
          anchorDay: 15,
        ),
        DateTime(2027, 1, 15),
      );
    });

    test('ohne Anker: Tag von d gilt als Anker', () {
      expect(
        advanceDate(DateTime(2026, 1, 20), IntervalUnit.month, 1),
        DateTime(2026, 2, 20),
      );
    });
  });

  group('advanceDate – Jahr', () {
    test('12 Monate weiter, Anker bleibt', () {
      expect(
        advanceDate(DateTime(2026, 2, 28), IntervalUnit.year, 1, anchorDay: 28),
        DateTime(2027, 2, 28),
      );
    });
  });
}
