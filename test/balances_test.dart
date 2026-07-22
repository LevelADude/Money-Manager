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

  group('accountBalancesCents (ein Durchlauf für alle Konten)', () {
    test('liefert je Konto exakt dasselbe wie accountBalanceCents', () {
      final accounts = [
        _acc('A', opening: 5000),
        _acc('B', opening: -200),
        _acc('C', opening: 0),
      ];
      final carryover = {'A': 700, 'C': -50};
      final txs = [
        _tx(type: TransactionType.income, accountId: 'A', amountCents: 2000),
        _tx(type: TransactionType.expense, accountId: 'A', amountCents: 500),
        _tx(type: TransactionType.expense, accountId: 'B', amountCents: 125),
        _tx(
          type: TransactionType.transfer,
          accountId: 'A',
          transferAccountId: 'B',
          amountCents: 400,
        ),
        _tx(
          type: TransactionType.transfer,
          accountId: 'C',
          transferAccountId: 'A',
          amountCents: 90,
        ),
        _tx(type: TransactionType.income, accountId: 'C', amountCents: 33),
      ];

      final bulk = accountBalancesCents(accounts, txs, carryover);
      for (final a in accounts) {
        expect(
          bulk[a.id],
          accountBalanceCents(a, txs, carryover),
          reason: 'Saldo von ${a.id} weicht ab',
        );
      }
    });

    test('Konten ganz ohne Buchungen sind enthalten', () {
      final accounts = [_acc('A', opening: 1000), _acc('B', opening: 250)];
      final bulk = accountBalancesCents(accounts, const [], {'B': 40});
      expect(bulk['A'], 1000);
      expect(bulk['B'], 290);
    });

    test('Buchungen auf unbekannte Konten werden ignoriert', () {
      final accounts = [_acc('A', opening: 0)];
      final txs = [
        // Fremdes Quellkonto (z. B. nur-ansehbares Konto ohne Freigabe).
        _tx(type: TransactionType.income, accountId: 'X', amountCents: 999),
        // Übertrag von A auf ein nicht geladenes Konto: A wird belastet,
        // für X entsteht kein Eintrag.
        _tx(
          type: TransactionType.transfer,
          accountId: 'A',
          transferAccountId: 'X',
          amountCents: 100,
        ),
      ];
      final bulk = accountBalancesCents(accounts, txs, const {});
      expect(bulk['A'], -100);
      expect(bulk.containsKey('X'), isFalse);
    });

    test('Übertrag ohne Zielkonto belastet nur das Quellkonto', () {
      final accounts = [_acc('A', opening: 500)];
      final txs = [
        _tx(type: TransactionType.transfer, accountId: 'A', amountCents: 200),
      ];
      expect(accountBalancesCents(accounts, txs, const {})['A'], 300);
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
