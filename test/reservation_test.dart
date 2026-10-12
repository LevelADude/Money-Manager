import 'package:flutter_test/flutter_test.dart';
import 'package:money_manager/data/models/recurring_rule.dart';
import 'package:money_manager/data/models/reservation.dart';
import 'package:money_manager/features/reservations/reserved_hint.dart';

Reservation _res(
  String accountId,
  int cents, {
  String id = 'r',
  DateTime? dueOn,
  int? topup,
  IntervalUnit? unit,
  DateTime? start,
  int count = 0,
  int? target,
}) => Reservation(
  id: id,
  accountId: accountId,
  name: 'x',
  amountCents: cents,
  dueOn: dueOn,
  topupCents: topup,
  topupUnit: unit,
  topupStart: start,
  topupCount: count,
  targetCents: target,
);

void main() {
  group('reservedByAccount / availableBalances', () {
    test('summiert je Konto und zieht vom Saldo ab', () {
      final reserved = reservedByAccount([
        _res('A', 300),
        _res('A', 200),
        _res('B', 50),
        _res('B', 0), // leere Rücklage zählt nicht
      ]);
      expect(reserved, {'A': 500, 'B': 50});
      final available = availableBalances({
        'A': 1000,
        'B': 20,
        'C': 70,
      }, reserved);
      expect(available, {'A': 500, 'B': -30, 'C': 70});
    });
  });

  group('isOverReserved', () {
    test('Vermögenskonto: nur wenn verfügbar < 0', () {
      expect(
        isOverReserved(
          balanceCents: 1000,
          reservedCents: 1000,
          isLiability: false,
        ),
        isFalse,
      );
      expect(
        isOverReserved(
          balanceCents: 1000,
          reservedCents: 1001,
          isLiability: false,
        ),
        isTrue,
      );
    });

    test('nichts reserviert -> nie überreserviert (auch bei Minus)', () {
      expect(
        isOverReserved(
          balanceCents: -500,
          reservedCents: 0,
          isLiability: false,
        ),
        isFalse,
      );
    });

    test('Kreditkarte: gegen den Rahmen, ohne Rahmen keine Warnung', () {
      // Rahmen 1000, Schuld 600 -> 400 frei.
      expect(
        isOverReserved(
          balanceCents: -600,
          reservedCents: 400,
          isLiability: true,
          creditLimitCents: 1000,
        ),
        isFalse,
      );
      expect(
        isOverReserved(
          balanceCents: -600,
          reservedCents: 401,
          isLiability: true,
          creditLimitCents: 1000,
        ),
        isTrue,
      );
      expect(
        isOverReserved(
          balanceCents: -600,
          reservedCents: 5000,
          isLiability: true,
        ),
        isFalse,
      );
    });
  });

  group('primaryAmount', () {
    test('verfügbar oder gesamt je nach Einstellung', () {
      expect(primaryAmount(1000, 300, true), 700);
      expect(primaryAmount(1000, 300, false), 1000);
    });
  });

  group('Reservation', () {
    test('nextTopup folgt dem Start ohne Monatsende-Drift', () {
      final r = _res(
        'A',
        0,
        topup: 50,
        unit: IntervalUnit.month,
        start: DateTime(2026, 1, 31),
        count: 1,
      );
      expect(r.nextTopup, DateTime(2026, 2, 28));
      final later = _res(
        'A',
        0,
        topup: 50,
        unit: IntervalUnit.month,
        start: DateTime(2026, 1, 31),
        count: 2,
      );
      expect(later.nextTopup, DateTime(2026, 3, 31));
    });

    test('nextTopup ist null bei erreichtem Ziel oder ohne Rhythmus', () {
      expect(_res('A', 100).nextTopup, isNull);
      expect(
        _res(
          'A',
          600,
          topup: 50,
          unit: IntervalUnit.month,
          start: DateTime(2026, 1, 1),
          target: 600,
        ).nextTopup,
        isNull,
      );
    });

    test('daysUntilDue ignoriert die Uhrzeit', () {
      final r = _res('A', 1, dueOn: DateTime(2026, 10, 15));
      expect(r.daysUntilDue(DateTime(2026, 10, 12, 23, 59)), 3);
      expect(r.daysUntilDue(DateTime(2026, 10, 16)), -1);
      expect(_res('A', 1).daysUntilDue(DateTime(2026)), isNull);
    });

    test('fromJson liest alle Felder', () {
      final r = Reservation.fromJson({
        'id': 'id1',
        'account_id': 'A',
        'name': 'Laptop',
        'amount_cents': 89900,
        'due_on': '2026-11-01',
        'category_id': 'c1',
        'note': 'n',
        'target_cents': null,
        'topup_cents': 5000,
        'topup_unit': 'year',
        'topup_start': '2026-01-15',
        'topup_count': 3,
      });
      expect(r.name, 'Laptop');
      expect(r.amountCents, 89900);
      expect(r.dueOn, DateTime(2026, 11, 1));
      expect(r.isRecurring, isTrue);
      expect(r.topupUnit, IntervalUnit.year);
      expect(r.nextTopup, DateTime(2029, 1, 15));
    });
  });
}
