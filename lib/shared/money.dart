import 'package:intl/intl.dart';

/// Geldbeträge werden intern als **Ganzzahl in Cent** gespeichert
/// (exakt + speichersparend). Hier Konvertierung/Formatierung + ein kleiner
/// sicherer Rechner fürs Betragsfeld.

/// Aktuelle Hauptwährung (wird aus den Einstellungen gesetzt). [formatCents]
/// formatiert standardmäßig in dieser Währung.
String gBaseCurrency = 'EUR';

const currencySymbols = <String, String>{
  'EUR': '€',
  'USD': '\$',
  'GBP': '£',
  'CHF': 'CHF',
  'JPY': '¥',
  'PLN': 'zł',
  'SEK': 'kr',
  'NOK': 'kr',
  'DKK': 'kr',
  'CZK': 'Kč',
  'TRY': '₺',
  'CAD': 'CA\$',
  'AUD': 'A\$',
  'USDT': 'USDT',
};

String currencySymbol(String code) => currencySymbols[code] ?? code;

/// Formatiert Cent in der angegebenen Währung.
String formatMoney(int cents, String code) => NumberFormat.currency(
  locale: 'de_DE',
  symbol: currencySymbol(code),
).format(cents / 100);

/// Formatiert in der Hauptwährung.
String formatCents(int cents) => formatMoney(cents, gBaseCurrency);

/// Cent -> bearbeitbarer Eingabe-String ("12,50").
String centsToInput(int cents) =>
    (cents / 100).toStringAsFixed(2).replaceAll('.', ',');

/// Formatiert eine Byte-Größe menschenlesbar ("12 MB", "1,5 GB").
/// Basis 1024; bis MB ohne, ab MB mit einer Nachkommastelle.
String formatBytes(int bytes) {
  if (bytes < 1024) return '$bytes B';
  const units = ['KB', 'MB', 'GB', 'TB'];
  var value = bytes / 1024;
  var unit = 0;
  while (value >= 1024 && unit < units.length - 1) {
    value /= 1024;
    unit++;
  }
  final digits = unit == 0 ? 0 : 1; // KB ganzzahlig, ab MB eine Nachkommastelle
  return '${value.toStringAsFixed(digits).replaceAll('.', ',')} ${units[unit]}';
}

/// Parst eine Nutzereingabe ODER einen Rechenausdruck ("12,50 + 3 + 7,99")
/// nach Cent. Gibt null zurück, wenn nichts Sinnvolles erkannt wird.
int? parseToCents(String input) {
  final value = evalExpression(input);
  if (value == null) return null;
  return (value * 100).round();
}

/// Wertet einen einfachen Rechenausdruck aus: + - * / und Klammern.
/// Komma gilt als Dezimaltrenner. Gibt null bei Fehler zurück.
double? evalExpression(String input) {
  final s = input
      .trim()
      .replaceAll('€', '')
      .replaceAll(' ', '')
      .replaceAll(',', '.');
  if (s.isEmpty) return null;

  // --- Tokenisierung (mit unärem Minus/Plus) ---
  final tokens = <String>[];
  final num = StringBuffer();
  var expectOperand = true;
  void flush() {
    if (num.isNotEmpty) {
      tokens.add(num.toString());
      num.clear();
    }
  }

  for (var i = 0; i < s.length; i++) {
    final ch = s[i];
    if ((ch.codeUnitAt(0) >= 48 && ch.codeUnitAt(0) <= 57) || ch == '.') {
      num.write(ch);
      expectOperand = false;
    } else if (ch == '(') {
      flush();
      tokens.add('(');
      expectOperand = true;
    } else if (ch == ')') {
      flush();
      tokens.add(')');
      expectOperand = false;
    } else if (ch == '+' || ch == '-' || ch == '*' || ch == '/') {
      if (expectOperand) {
        if (ch == '-') {
          num.write('-'); // unäres Minus in die Zahl
        } else if (ch != '+') {
          return null; // * oder / können nicht unär sein
        }
        // unäres + wird ignoriert; weiterhin Operand erwartet
      } else {
        flush();
        tokens.add(ch);
        expectOperand = true;
      }
    } else {
      return null; // unerlaubtes Zeichen
    }
  }
  flush();
  if (tokens.isEmpty) return null;

  // --- Shunting-Yard -> RPN ---
  const prec = {'+': 1, '-': 1, '*': 2, '/': 2};
  final output = <String>[];
  final ops = <String>[];
  for (final t in tokens) {
    if (double.tryParse(t) != null) {
      output.add(t);
    } else if (prec.containsKey(t)) {
      while (ops.isNotEmpty &&
          prec.containsKey(ops.last) &&
          prec[ops.last]! >= prec[t]!) {
        output.add(ops.removeLast());
      }
      ops.add(t);
    } else if (t == '(') {
      ops.add(t);
    } else if (t == ')') {
      while (ops.isNotEmpty && ops.last != '(') {
        output.add(ops.removeLast());
      }
      if (ops.isEmpty) return null; // unbalancierte Klammern
      ops.removeLast();
    }
  }
  while (ops.isNotEmpty) {
    final op = ops.removeLast();
    if (op == '(') return null;
    output.add(op);
  }

  // --- RPN auswerten ---
  final stack = <double>[];
  for (final t in output) {
    final n = double.tryParse(t);
    if (n != null) {
      stack.add(n);
    } else {
      if (stack.length < 2) return null;
      final b = stack.removeLast();
      final a = stack.removeLast();
      switch (t) {
        case '+':
          stack.add(a + b);
        case '-':
          stack.add(a - b);
        case '*':
          stack.add(a * b);
        case '/':
          if (b == 0) return null;
          stack.add(a / b);
      }
    }
  }
  if (stack.length != 1) return null;
  return stack.first;
}
