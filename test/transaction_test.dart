import 'package:flutter_test/flutter_test.dart';
import 'package:money_manager/data/models/app_transaction.dart';

AppTransaction _tx({
  required TransactionType type,
  required String accountId,
  String? transferAccountId,
  int amountCents = 1000,
  List<String> tags = const [],
}) {
  return AppTransaction(
    id: 't1',
    accountId: accountId,
    type: type,
    amountCents: amountCents,
    occurredOn: DateTime(2026, 1, 1),
    categoryId: null,
    transferAccountId: transferAccountId,
    title: '',
    note: '',
    createdBy: null,
    receiptPath: null,
    tags: tags,
  );
}

void main() {
  group('signedCentsFor', () {
    test('Einnahme zählt nur für das eigene Konto', () {
      final t = _tx(type: TransactionType.income, accountId: 'A');
      expect(t.signedCentsFor('A'), 1000);
      expect(t.signedCentsFor('B'), 0);
    });

    test('Ausgabe ist negativ für das eigene Konto', () {
      final t = _tx(type: TransactionType.expense, accountId: 'A');
      expect(t.signedCentsFor('A'), -1000);
      expect(t.signedCentsFor('B'), 0);
    });

    test('Übertrag: Abgang beim Quellkonto, Zugang beim Zielkonto', () {
      final t = _tx(
        type: TransactionType.transfer,
        accountId: 'A',
        transferAccountId: 'B',
        amountCents: 500,
      );
      expect(t.signedCentsFor('A'), -500);
      expect(t.signedCentsFor('B'), 500);
      expect(t.signedCentsFor('C'), 0);
    });
  });

  group('fromJson Tags', () {
    test('Tags als Liste', () {
      final t = AppTransaction.fromJson({
        'id': 'x',
        'account_id': 'A',
        'type': 'expense',
        'amount_cents': 100,
        'occurred_on': '2026-01-01',
        'tags': ['Urlaub', 'Bar'],
      });
      expect(t.tags, ['Urlaub', 'Bar']);
    });

    test('Tags als Postgres-Array-String', () {
      final t = AppTransaction.fromJson({
        'id': 'x',
        'account_id': 'A',
        'type': 'expense',
        'amount_cents': 100,
        'occurred_on': '2026-01-01',
        'tags': '{Urlaub,"Mit Komma"}',
      });
      expect(t.tags, ['Urlaub', 'Mit Komma']);
    });

    test('Keine Tags', () {
      final t = AppTransaction.fromJson({
        'id': 'x',
        'account_id': 'A',
        'type': 'income',
        'amount_cents': 100,
        'occurred_on': '2026-01-01',
      });
      expect(t.tags, isEmpty);
    });
  });
}
