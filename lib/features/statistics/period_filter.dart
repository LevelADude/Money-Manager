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

const _statMonths = [
  'Januar', 'Februar', 'März', 'April', 'Mai', 'Juni',
  'Juli', 'August', 'September', 'Oktober', 'November', 'Dezember',
];

/// Bezugsdatum für die Statistik (welcher Tag/Woche/Monat/Jahr angezeigt wird).
class StatsAnchorNotifier extends Notifier<DateTime> {
  @override
  DateTime build() => DateTime.now();

  void shift(StatsPeriod p, int dir) => state = p.shifted(state, dir);
  void reset() => state = DateTime.now();
}

final statsAnchorProvider =
    NotifierProvider<StatsAnchorNotifier, DateTime>(StatsAnchorNotifier.new);

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

  /// Lesbare Bezeichnung des aktuellen Zeitfensters (ohne intl-Locale-Daten).
  String labelFor(DateTime a) {
    String d2(int n) => n.toString().padLeft(2, '0');
    switch (this) {
      case StatsPeriod.thisDay:
        return '${d2(a.day)}.${d2(a.month)}.${a.year}';
      case StatsPeriod.thisWeek:
        final start = a.subtract(Duration(days: a.weekday - 1));
        final end = start.add(const Duration(days: 6));
        return '${d2(start.day)}.${d2(start.month)}. – '
            '${d2(end.day)}.${d2(end.month)}.${end.year}';
      case StatsPeriod.thisMonth:
        return '${_statMonths[a.month - 1]} ${a.year}';
      case StatsPeriod.thisYear:
        return '${a.year}';
      case StatsPeriod.all:
        return 'Gesamt';
    }
  }
}
