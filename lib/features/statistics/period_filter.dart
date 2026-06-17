import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Auswertungs-Zeitraum.
enum StatsPeriod { thisMonth, thisYear, all }

extension StatsPeriodX on StatsPeriod {
  String get label => switch (this) {
        StatsPeriod.thisMonth => 'Monat',
        StatsPeriod.thisYear => 'Jahr',
        StatsPeriod.all => 'Gesamt',
      };

  bool contains(DateTime d) {
    final now = DateTime.now();
    switch (this) {
      case StatsPeriod.thisMonth:
        return d.year == now.year && d.month == now.month;
      case StatsPeriod.thisYear:
        return d.year == now.year;
      case StatsPeriod.all:
        return true;
    }
  }
}

class PeriodNotifier extends Notifier<StatsPeriod> {
  @override
  StatsPeriod build() => StatsPeriod.thisMonth;

  void set(StatsPeriod p) => state = p;
}

final periodFilterProvider =
    NotifierProvider<PeriodNotifier, StatsPeriod>(PeriodNotifier.new);
