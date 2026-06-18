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
}
