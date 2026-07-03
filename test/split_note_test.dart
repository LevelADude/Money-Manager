// Verifiziert, dass die Freitext-Bezeichnung pro Teilsumme (Splits-Notiz)
// den Modell-Layer korrekt durchläuft.
import 'package:flutter_test/flutter_test.dart';
import 'package:money_manager/data/models/transaction_split.dart';

void main() {
  group('TransactionSplit.note', () {
    test('liest note aus der DB-Zeile', () {
      final s = TransactionSplit.fromJson({
        'id': 'a',
        'transaction_id': 'tx1',
        'category_id': null,
        'amount_cents': 1200,
        'note': '12 € Produkt A',
      });
      expect(s.note, '12 € Produkt A');
      expect(s.categoryId, isNull);
      expect(s.amountCents, 1200);
    });

    test('fehlende/null note wird zu leerem String (Altbestand)', () {
      final s = TransactionSplit.fromJson({
        'id': 'b',
        'transaction_id': 'tx1',
        'category_id': 'cat1',
        'amount_cents': 500,
        'note': null,
      });
      expect(s.note, '');
    });
  });
}
