import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Auswertungs-Zeitraum.
enum StatsPeriod { thisDay, thisWeek, thisMonth, thisYear, all }

class PeriodNotifier extends Notifier<StatsPeriod> {
  @override
  StatsPeriod build() => StatsPeriod.thisMonth;

  void set(StatsPeriod p) => state = p;
}

final periodFilterProvider = NotifierProvider<PeriodNotifier, StatsPeriod>(
  PeriodNotifier.new,
);

/// Bezugsdatum für die Statistik (welcher Tag/Woche/Monat/Jahr angezeigt wird).
class StatsAnchorNotifier extends Notifier<DateTime> {
  @override
  DateTime build() => DateTime.now();

  void shift(StatsPeriod p, int dir) => state = p.shifted(state, dir);
  void reset() => state = DateTime.now();
}

final statsAnchorProvider = NotifierProvider<StatsAnchorNotifier, DateTime>(
  StatsAnchorNotifier.new,
);

extension StatsPeriodNav on StatsPeriod {
  /// Verschiebt das Bezugsdatum um [dir] Perioden (–1 zurück, +1 vor).
  DateTime shifted(DateTime a, int dir) {
    switch (this) {
      case StatsPeriod.thisDay:
        return a.add(Duration(days: dir));
      case StatsPeriod.thisWeek:
        return a.add(Duration(days: 7 * dir));
      case StatsPeriod.thisMonth:
        return DateTime(a.year, a.month + dir, 1);
      case StatsPeriod.thisYear:
        return DateTime(a.year + dir, 1, 1);
      case StatsPeriod.all:
        return a;
    }
  }
}
