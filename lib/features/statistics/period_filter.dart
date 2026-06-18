import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Auswertungs-Zeitraum.
enum StatsPeriod { thisDay, thisWeek, thisMonth, thisYear, all }

extension StatsPeriodX on StatsPeriod {
  String get label => switch (this) {
        StatsPeriod.thisDay => 'Tag',
        StatsPeriod.thisWeek => 'Woche',
        StatsPeriod.thisMonth => 'Monat',
        StatsPeriod.thisYear => 'Jahr',
        StatsPeriod.all => 'Gesamt',
      };

  bool contains(DateTime d) {
    final now = DateTime.now();
    switch (this) {
      case StatsPeriod.thisDay:
        return d.year == now.year && d.month == now.month && d.day == now.day;
      case StatsPeriod.thisWeek:
        final today = DateTime(now.year, now.month, now.day);
        final start = today.subtract(Duration(days: today.weekday - 1));
        final end = start.add(const Duration(days: 7));
        final day = DateTime(d.year, d.month, d.day);
        return !day.isBefore(start) && day.isBefore(end);
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
