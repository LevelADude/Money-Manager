import 'package:flutter_test/flutter_test.dart';
import 'package:money_manager/data/models/account.dart';
import 'package:money_manager/data/models/app_transaction.dart';
import 'package:money_manager/data/models/recurring_rule.dart';
import 'package:money_manager/data/models/reservation.dart';
import 'package:money_manager/features/planning/cashflow_projection.dart';

Account _acc(
  String id, {
  String currency = 'EUR',
  bool inNetWorth = true,
  bool archived = false,
}) => Account(
  id: id,
  ownerId: 'me',
  name: id,
  type: AccountType.bank,
  currency: currency,
  openingBalanceCents: 0,
  icon: null,
  color: null,
  creditLimitCents: null,
  includeInNetWorth: inNetWorth,
  archived: archived,
);

RecurringRule _rule(
  String accountId,
  TransactionType type,
  int cents, {
  String? to,
  DateTime? nextDue,
}) => RecurringRule(
  id: 'r',
  accountId: accountId,
  type: type,
  amountCents: cents,
  categoryId: null,
  transferAccountId: to,
  title: 'x',
  note: '',
  intervalUnit: IntervalUnit.month,
  intervalCount: 1,
  nextDue: nextDue ?? DateTime(2026, 10, 20),
  endDate: null,
  active: true,
  anchorDay: (nextDue ?? DateTime(2026, 10, 20)).day,
);

// 1 EUR = 300 PKR ("RS"): Fremdwährung wird durch 300 geteilt.
int _convert(int cents, String currency) =>
    currency == 'RS' ? (cents / 300).round() : cents;

CashflowProjection _project({
  required List<Account> accounts,
  required Map<String, int> balances,
  List<RecurringRule> rules = const [],
  List<Reservation> reservations = const [],
}) => projectCashflow(
  accounts: accounts,
  balances: balances,
  rules: rules,
  reservations: reservations,
  convert: _convert,
  today: DateTime(2026, 10, 12),
  horizon: DateTime(2026, 12, 11),
  ruleTitle: (r) => r.title,
  reservationTitle: (r) => r.name,
);

void main() {
  test('rechnet Fremdwährung um statt sie als Euro zu addieren', () {
    final p = _project(
      accounts: [
        _acc('eur'),
        _acc('pk', currency: 'RS'),
      ],
      balances: {'eur': 25689, 'pk': 394500000},
    );
    // 3.945.000,00 RS / 300 = 13.150,00 EUR
    expect(p.current, 25689 + 1315000);
  });

  test('ignoriert Konten außerhalb des Vermögens und archivierte', () {
    final p = _project(
      accounts: [
        _acc('a'),
        _acc('depot', inNetWorth: false),
        _acc('alt', archived: true),
      ],
      balances: {'a': 100, 'depot': 316500, 'alt': 999},
    );
    expect(p.current, 100);
  });

  test('Daueraufträge auf fremden/ausgeschlossenen Konten zählen nicht', () {
    final p = _project(
      accounts: [_acc('a')],
      balances: {'a': 0},
      rules: [
        _rule('a', TransactionType.income, 20000),
        _rule('other', TransactionType.expense, 5000),
      ],
    );
    // 20.10., 20.11. im Horizont (bis 11.12.)
    expect(p.events.map((e) => e.signed), [20000, 20000]);
  });

  test('Übertrag zählt nur, wenn er den Umfang verlässt oder erreicht', () {
    final p = _project(
      accounts: [_acc('a'), _acc('b')],
      balances: {'a': 0, 'b': 0},
      rules: [
        _rule('a', TransactionType.transfer, 1000, to: 'b'), // intern
        _rule('a', TransactionType.transfer, 300, to: 'x'), // raus
        _rule('x', TransactionType.transfer, 700, to: 'b'), // rein
      ],
    );
    final sums = p.events.map((e) => e.signed).toSet();
    expect(sums, {-300, 700});
    expect(p.events.length, 4); // je 2 Termine
  });

  test('Ausgaben in Fremdwährung werden umgerechnet', () {
    final p = _project(
      accounts: [_acc('pk', currency: 'RS')],
      balances: {'pk': 0},
      rules: [_rule('pk', TransactionType.expense, 30000)],
    );
    expect(p.events.first.signed, -100);
  });

  test('Reservierungen: nur im Umfang, umgerechnet, überfällige heute', () {
    final p = _project(
      accounts: [_acc('pk', currency: 'RS')],
      balances: {'pk': 0},
      reservations: [
        Reservation(
          id: '1',
          accountId: 'pk',
          name: 'alt',
          amountCents: 60000,
          dueOn: DateTime(2026, 10, 1),
        ),
        Reservation(
          id: '2',
          accountId: 'fremd',
          name: 'fremd',
          amountCents: 500,
          dueOn: DateTime(2026, 10, 20),
        ),
        Reservation(
          id: '3',
          accountId: 'pk',
          name: 'ohne Datum',
          amountCents: 500,
        ),
      ],
    );
    expect(p.events, hasLength(1));
    expect(p.events.single.date, DateTime(2026, 10, 12));
    expect(p.events.single.signed, -200);
    expect(p.events.single.isReservation, isTrue);
  });
}
