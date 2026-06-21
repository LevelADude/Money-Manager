import 'receipt_scan.dart';

/// Zieht Betrag, Datum und Händler aus rohem Beleg-Text (OCR-Ausgabe).
/// Reine Heuristik, keine Plattform-/Netz-Abhängigkeit – daher gut testbar.

// Geldbeträge wie "12,50" oder "1.234,56" -> hier vereinfacht auf "<euro>[.,]<cent>".
final _amountRe = RegExp(r'(\d{1,4})[.,](\d{2})(?!\d)');
// Tag-Monat-Jahr: 31.12.2024 / 31-12-24 / 31/12/2024
final _dateRe = RegExp(r'(\d{1,2})[.\-/](\d{1,2})[.\-/](\d{2,4})');
// ISO: 2024-12-31
final _isoDateRe = RegExp(r'(\d{4})-(\d{1,2})-(\d{1,2})');

// Zeilen, die auf den Gesamtbetrag hindeuten (bewusst ohne "eur" – zu häufig).
const _totalKeywords = [
  'summe', 'gesamt', 'total', 'zu zahlen', 'zahlbetrag', 'betrag',
];

// Generische Kopfzeilen, die kein Händlername sind.
const _merchantSkip = [
  'rechnung', 'quittung', 'beleg', 'kassenbon', 'tel', 'telefon',
  'www', 'http', 'datum', 'uhrzeit', 'steuer', 'ust',
];

ReceiptScan parseReceiptText(String raw) {
  final lines = raw
      .split('\n')
      .map((l) => l.trim())
      .where((l) => l.isNotEmpty)
      .toList();
  return ReceiptScan(
    amountCents: _extractAmount(lines),
    date: _extractDate(raw),
    merchant: _extractMerchant(lines),
    rawText: raw,
  );
}

int? _centsFrom(RegExpMatch m) {
  final euros = int.tryParse(m.group(1)!);
  final cents = int.tryParse(m.group(2)!);
  if (euros == null || cents == null) return null;
  return euros * 100 + cents;
}

int? _extractAmount(List<String> lines) {
  int? keywordBest; // größter Betrag auf einer "Summe/Total"-Zeile
  int? overallMax; // größter Betrag überhaupt (Fallback)
  for (final line in lines) {
    final lower = line.toLowerCase();
    final hasKw = _totalKeywords.any(lower.contains);
    for (final m in _amountRe.allMatches(line)) {
      final cents = _centsFrom(m);
      if (cents == null || cents <= 0) continue;
      if (cents > (overallMax ?? -1)) overallMax = cents;
      if (hasKw && cents > (keywordBest ?? -1)) keywordBest = cents;
    }
  }
  return keywordBest ?? overallMax;
}

DateTime? _buildDate(int day, int month, int year) {
  if (month < 1 || month > 12 || day < 1 || day > 31) return null;
  if (year < 2000 || year > 2100) return null;
  final d = DateTime(year, month, day);
  // Plausibilität: Tag/Monat dürfen durch DateTime nicht "übergelaufen" sein.
  if (d.day != day || d.month != month) return null;
  return d;
}

DateTime? _extractDate(String raw) {
  for (final m in _isoDateRe.allMatches(raw)) {
    final d = _buildDate(
        int.parse(m.group(3)!), int.parse(m.group(2)!), int.parse(m.group(1)!));
    if (d != null) return d;
  }
  for (final m in _dateRe.allMatches(raw)) {
    var year = int.parse(m.group(3)!);
    if (year < 100) year += 2000;
    final d = _buildDate(int.parse(m.group(1)!), int.parse(m.group(2)!), year);
    if (d != null) return d;
  }
  return null;
}

final _letters = RegExp(r'[A-Za-zÄÖÜäöüß]');

String? _extractMerchant(List<String> lines) {
  for (final line in lines.take(6)) {
    final lower = line.toLowerCase();
    if (_merchantSkip.any(lower.contains)) continue;
    if (_dateRe.hasMatch(line) || _isoDateRe.hasMatch(line)) continue;
    final letterCount = _letters.allMatches(line).length;
    if (letterCount < 3) continue; // keine echten Wörter
    // Zeilen, die fast nur aus Zahlen bestehen, überspringen.
    final compact = line.replaceAll(' ', '');
    if (compact.isNotEmpty && letterCount < compact.length / 2) continue;
    return _titleCase(line);
  }
  return null;
}

String _titleCase(String s) {
  final words = s.split(RegExp(r'\s+')).where((w) => w.isNotEmpty);
  final result = words
      .map((w) => w.length == 1
          ? w.toUpperCase()
          : w[0].toUpperCase() + w.substring(1).toLowerCase())
      .join(' ');
  return result.length > 40 ? result.substring(0, 40).trim() : result;
}
