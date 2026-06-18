import 'package:flutter_test/flutter_test.dart';
import 'package:money_manager/features/statistics/period_filter.dart';

void main() {
  final now = DateTime.now();

  group('StatsPeriod.contains', () {
    test('Gesamt enthält alles', () {
      expect(StatsPeriod.all.contains(DateTime(1999, 1, 1)), isTrue);
      expect(StatsPeriod.all.contains(DateTime(2099, 12, 31)), isTrue);
    });

    test('Jahr enthält dieses Jahr, nicht das letzte', () {
      expect(StatsPeriod.thisYear.contains(DateTime(now.year, 1, 1)), isTrue);
      expect(
          StatsPeriod.thisYear.contains(DateTime(now.year - 1, 6, 15)), isFalse);
    });

    test('Monat enthält diesen Monat, nicht ein anderes Jahr', () {
      expect(
          StatsPeriod.thisMonth.contains(DateTime(now.year, now.month, 1)),
          isTrue);
      expect(
          StatsPeriod.thisMonth.contains(DateTime(now.year - 1, now.month, 1)),
          isFalse);
    });
  });

  group('Labels', () {
    test('deutsche Beschriftungen', () {
      expect(StatsPeriod.thisMonth.label, 'Monat');
      expect(StatsPeriod.thisYear.label, 'Jahr');
      expect(StatsPeriod.all.label, 'Gesamt');
    });
  });

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
      expect(StatsPeriod.thisMonth.shifted(DateTime(2026, 1, 10), -1),
          DateTime(2025, 12, 1));
      expect(StatsPeriod.thisMonth.shifted(DateTime(2026, 12, 10), 1),
          DateTime(2027, 1, 1));
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

  group('StatsPeriodNav.labelFor (Anzeige des Zeitraums)', () {
    test('Monat zeigt deutschen Monatsnamen + Jahr', () {
      expect(StatsPeriod.thisMonth.labelFor(DateTime(2026, 3, 15)), 'März 2026');
      expect(StatsPeriod.thisMonth.labelFor(DateTime(2025, 12, 1)),
          'Dezember 2025');
    });

    test('Jahr zeigt die Jahreszahl', () {
      expect(StatsPeriod.thisYear.labelFor(DateTime(2026, 7, 1)), '2026');
    });

    test('Tag zeigt dd.MM.yyyy', () {
      expect(StatsPeriod.thisDay.labelFor(DateTime(2026, 3, 5)), '05.03.2026');
    });

    test('Woche zeigt Mo–So-Spanne', () {
      // 15.03.2026 ist ein Sonntag -> Woche Mo 09.03. bis So 15.03.
      expect(StatsPeriod.thisWeek.labelFor(DateTime(2026, 3, 15)),
          '09.03. – 15.03.2026');
    });

    test('Gesamt zeigt "Gesamt"', () {
      expect(StatsPeriod.all.labelFor(DateTime(2026, 3, 15)), 'Gesamt');
    });
  });
}
