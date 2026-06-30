import 'package:flutter_test/flutter_test.dart';
import 'package:money_manager/data/models/account.dart';
import 'package:money_manager/data/models/app_transaction.dart';
import 'package:money_manager/shared/balances.dart';

Account _acc(String id, {int opening = 0}) => Account(
  id: id,
  ownerId: 'owner',
  name: id,
  type: AccountType.bank,
  currency: 'EUR',
  openingBalanceCents: opening,
  icon: null,
  color: null,
  creditLimitCents: null,
  includeInNetWorth: true,
  archived: false,
);

AppTransaction _tx({
  required TransactionType type,
  required String accountId,
  String? transferAccountId,
  int amountCents = 1000,
  DateTime? on,
}) => AppTransaction(
  id: 't',
  accountId: accountId,
  type: type,
  amountCents: amountCents,
  occurredOn: on ?? DateTime(2026, 1, 1),
  categoryId: null,
  transferAccountId: transferAccountId,
  title: '',
  note: '',
  createdBy: null,
  receiptPath: null,
);

void main() {
  group('accountBalanceCents', () {
    test('Anfangssaldo + Buchungen, ohne Carry-over', () {
      final a = _acc('A', opening: 5000);
      final txs = [
        _tx(type: TransactionType.income, accountId: 'A', amountCents: 2000),
        _tx(type: TransactionType.expense, accountId: 'A', amountCents: 500),
      ];
      expect(accountBalanceCents(a, txs, const {}), 5000 + 2000 - 500);
    });

    test('Carry-over wird addiert', () {
      final a = _acc('A', opening: 1000);
      final txs = [
        _tx(type: TransactionType.income, accountId: 'A', amountCents: 300),
      ];
      expect(accountBalanceCents(a, txs, {'A': 7000}), 1000 + 7000 + 300);
    });

    test('Konto ohne Carry-over-Eintrag wird wie 0 behandelt', () {
      final a = _acc('A', opening: 1000);
      expect(accountBalanceCents(a, const [], {'B': 5000}), 1000);
    });

    test('Übertrag fließt korrekt in beide Konten', () {
      final a = _acc('A', opening: 1000);
      final b = _acc('B', opening: 0);
      final txs = [
        _tx(
          type: TransactionType.transfer,
          accountId: 'A',
          transferAccountId: 'B',
          amountCents: 400,
        ),
      ];
      expect(accountBalanceCents(a, txs, const {}), 600);
      expect(accountBalanceCents(b, txs, const {}), 400);
    });
  });

  group('accountBalanceAsOf', () {
    test('zählt nur Buchungen bis einschließlich asOf', () {
      final a = _acc('A', opening: 0);
      final txs = [
        _tx(
          type: TransactionType.income,
          accountId: 'A',
          amountCents: 100,
          on: DateTime(2026, 1, 10),
        ),
        _tx(
          type: TransactionType.income,
          accountId: 'A',
          amountCents: 200,
          on: DateTime(2026, 2, 10),
        ),
      ];
      expect(accountBalanceAsOf(a, txs, const {}, DateTime(2026, 1, 31)), 100);
      expect(accountBalanceAsOf(a, txs, const {}, DateTime(2026, 2, 28)), 300);
    });

    test('Carry-over zählt immer mit (auch am frühesten Stichtag)', () {
      final a = _acc('A', opening: 0);
      final txs = [
        _tx(
          type: TransactionType.income,
          accountId: 'A',
          amountCents: 100,
          on: DateTime(2026, 6, 1),
        ),
      ];
      // Stichtag vor der Buchung: nur Carry-over.
      expect(
        accountBalanceAsOf(a, txs, {'A': 5000}, DateTime(2026, 1, 1)),
        5000,
      );
    });
  });
}
