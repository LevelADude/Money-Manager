import 'package:intl/intl.dart';

/// Geldbeträge werden intern als **Ganzzahl in Cent** gespeichert
/// (exakt + speichersparend). Hier die Konvertierung/Formatierung.
final NumberFormat _eur = NumberFormat.currency(locale: 'de_DE', symbol: '€');

String formatCents(int cents) => _eur.format(cents / 100);

/// Parst eine Nutzereingabe ("12,50", "12.50", "1.234,56 €") nach Cent.
/// Gibt null zurück, wenn nichts Sinnvolles erkannt wird.
int? parseToCents(String input) {
  var s = input.trim();
  if (s.isEmpty) return null;
  // Tausenderpunkte entfernen, Komma -> Punkt, dann alles außer Ziffern/Punkt/Minus weg.
  s = s.replaceAll('.', '').replaceAll(',', '.');
  s = s.replaceAll(RegExp(r'[^0-9.\-]'), '');
  if (s.isEmpty) return null;
  final value = double.tryParse(s);
  if (value == null) return null;
  return (value * 100).round();
}

/// Cent -> bearbeitbarer Eingabe-String ("12,50").
String centsToInput(int cents) =>
    (cents / 100).toStringAsFixed(2).replaceAll('.', ',');
