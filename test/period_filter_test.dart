import 'package:flutter_test/flutter_test.dart';
import 'package:money_manager/features/statistics/period_filter.dart';

void main() {
  group('StatsPeriodNav.shifted (Blättern)', () {
    final anchor = DateTime(2026, 3, 15);

    test('Tag: ein Tag vor/zurück', () {
      expect(StatsPeriod.thisDay.shifted(anchor, -1), DateTime(2026, 3, 14));
      expect(StatsPeriod.thisDay.shifted(anchor, 1), DateTime(2026, 3, 16));
    });

    test('Woche: sieben Tage vor/zurück', () {
      expect(StatsPeriod.thisWeek.shifted(anchor, -1), DateTime(2026, 3, 8));
      expect(StatsPeriod.thisWeek.shifted(anchor, 1), DateTime(2026, 3, 22));
    });

    test('Monat: auf den Monatsersten, Jahreswechsel korrekt', () {
      expect(StatsPeriod.thisMonth.shifted(anchor, -1), DateTime(2026, 2, 1));
      expect(StatsPeriod.thisMonth.shifted(anchor, 1), DateTime(2026, 4, 1));
      // Über die Jahresgrenze hinweg.
      expect(
        StatsPeriod.thisMonth.shifted(DateTime(2026, 1, 10), -1),
        DateTime(2025, 12, 1),
      );
      expect(
        StatsPeriod.thisMonth.shifted(DateTime(2026, 12, 10), 1),
        DateTime(2027, 1, 1),
      );
    });

    test('Jahr: auf den 1. Januar des Vor-/Folgejahres', () {
      expect(StatsPeriod.thisYear.shifted(anchor, -1), DateTime(2025, 1, 1));
      expect(StatsPeriod.thisYear.shifted(anchor, 1), DateTime(2027, 1, 1));
    });

    test('Gesamt: bleibt unverändert', () {
      expect(StatsPeriod.all.shifted(anchor, -1), anchor);
      expect(StatsPeriod.all.shifted(anchor, 1), anchor);
    });
  });
}
