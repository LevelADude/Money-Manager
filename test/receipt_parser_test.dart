import 'package:flutter_test/flutter_test.dart';
import 'package:money_manager/features/transactions/ocr/receipt_parser.dart';

void main() {
  group('parseReceiptText', () {
    test('erkennt Händler, Datum und Summe', () {
      const raw = '''
REWE Markt GmbH
Hauptstraße 5
12345 Musterstadt
Datum: 03.06.2026
Kaffee 3,49
Brot 2,19
Summe 5,68
EUR
''';
      final s = parseReceiptText(raw);
      expect(s.merchant, 'Rewe Markt Gmbh');
      expect(s.amountCents, 568); // bevorzugt die "Summe"-Zeile
      expect(s.date, DateTime(2026, 6, 3));
    });

    test('nimmt größten Betrag, wenn kein Summen-Stichwort', () {
      const raw = 'Aldi Süd\n2,00\n12,99\n4,50';
      final s = parseReceiptText(raw);
      expect(s.amountCents, 1299);
      expect(s.merchant, 'Aldi Süd');
    });

    test('akzeptiert ISO-Datum', () {
      final s = parseReceiptText('Edeka\nTotal 9,90\n2025-01-15');
      expect(s.date, DateTime(2025, 1, 15));
      expect(s.amountCents, 990);
    });

    test('leerer Text liefert nichts', () {
      final s = parseReceiptText('');
      expect(s.hasAnything, isFalse);
    });
  });
}
