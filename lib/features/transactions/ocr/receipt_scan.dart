/// Ergebnis einer Beleg-Texterkennung (OCR). Felder sind optional – was nicht
/// sicher erkannt wurde, bleibt null und wird im Formular nicht vorbefüllt.
class ReceiptScan {
  const ReceiptScan({
    this.amountCents,
    this.date,
    this.merchant,
    this.rawText = '',
  });

  /// Erkannter Gesamtbetrag in Cent (positiv) oder null.
  final int? amountCents;

  /// Erkanntes Belegdatum oder null.
  final DateTime? date;

  /// Erkannter Händler/Titel (oberste „textige" Zeile) oder null.
  final String? merchant;

  /// Roher erkannter Text (für Debug/Anzeige).
  final String rawText;

  /// True, wenn mindestens ein verwertbares Feld erkannt wurde.
  bool get hasAnything =>
      amountCents != null || date != null || merchant != null;
}
