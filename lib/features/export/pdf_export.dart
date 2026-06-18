import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

/// Erzeugt einen PDF-Bericht der Buchungen (Tabelle + Summen) und öffnet den
/// System-Dialog zum Teilen/Drucken/Speichern. Funktioniert auf Windows,
/// Android und Web.
///
/// [rows] sind bereits formatierte Zeilen in der Reihenfolge der Spalten
/// (Datum, Typ, Konto, Kategorie, Titel, Betrag).
Future<void> shareTransactionsPdf({
  required String heading,
  required String periodLabel,
  required List<List<String>> rows,
  required String incomeText,
  required String expenseText,
  required String balanceText,
  String filename = 'money-manager.pdf',
}) async {
  final doc = pw.Document();
  final headers = ['Datum', 'Typ', 'Konto', 'Kategorie', 'Titel', 'Betrag'];

  doc.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(28),
      header: (ctx) => ctx.pageNumber == 1
          ? pw.SizedBox()
          : pw.Container(
              alignment: pw.Alignment.centerRight,
              margin: const pw.EdgeInsets.only(bottom: 8),
              child: pw.Text(heading,
                  style: const pw.TextStyle(
                      fontSize: 9, color: PdfColors.grey600)),
            ),
      footer: (ctx) => pw.Container(
        alignment: pw.Alignment.centerRight,
        margin: const pw.EdgeInsets.only(top: 8),
        child: pw.Text('Seite ${ctx.pageNumber} / ${ctx.pagesCount}',
            style:
                const pw.TextStyle(fontSize: 9, color: PdfColors.grey600)),
      ),
      build: (ctx) => [
        pw.Header(
          level: 0,
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(heading,
                  style: pw.TextStyle(
                      fontSize: 20, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 2),
              pw.Text(periodLabel,
                  style: const pw.TextStyle(
                      fontSize: 11, color: PdfColors.grey700)),
            ],
          ),
        ),
        // Summen
        pw.Container(
          margin: const pw.EdgeInsets.only(bottom: 12),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              _summaryBox(label: 'Einnahmen', value: incomeText),
              _summaryBox(label: 'Ausgaben', value: expenseText),
              _summaryBox(label: 'Saldo', value: balanceText),
            ],
          ),
        ),
        if (rows.isEmpty)
          pw.Text('Keine Buchungen in diesem Zeitraum.')
        else
          pw.TableHelper.fromTextArray(
            headers: headers,
            data: rows,
            headerStyle: pw.TextStyle(
                fontWeight: pw.FontWeight.bold, fontSize: 10),
            headerDecoration:
                const pw.BoxDecoration(color: PdfColors.grey300),
            cellStyle: const pw.TextStyle(fontSize: 9),
            cellHeight: 18,
            cellAlignments: {
              0: pw.Alignment.centerLeft,
              1: pw.Alignment.centerLeft,
              2: pw.Alignment.centerLeft,
              3: pw.Alignment.centerLeft,
              4: pw.Alignment.centerLeft,
              5: pw.Alignment.centerRight,
            },
            columnWidths: {
              0: const pw.FlexColumnWidth(1.4),
              1: const pw.FlexColumnWidth(1.2),
              2: const pw.FlexColumnWidth(1.6),
              3: const pw.FlexColumnWidth(1.8),
              4: const pw.FlexColumnWidth(2.4),
              5: const pw.FlexColumnWidth(1.4),
            },
          ),
      ],
    ),
  );

  await Printing.sharePdf(bytes: await doc.save(), filename: filename);
}

// Hilfs-Widget für eine Summenkachel im PDF.
pw.Widget _summaryBox({required String label, required String value}) {
  return pw.Container(
    padding: const pw.EdgeInsets.all(8),
    decoration: pw.BoxDecoration(
      border: pw.Border.all(color: PdfColors.grey400),
      borderRadius: pw.BorderRadius.circular(4),
    ),
    child: pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(label,
            style:
                const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
        pw.SizedBox(height: 2),
        pw.Text(value,
            style:
                pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
      ],
    ),
  );
}
