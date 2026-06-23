import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';

import '../../data/models/account.dart';
import '../../data/models/app_transaction.dart';
import '../../l10n/app_localizations.dart';
import '../../shared/money.dart';
import '../accounts/account_providers.dart';
import '../categories/category_providers.dart';
import '../profile/profile_providers.dart';
import '../transactions/transaction_providers.dart';
import 'pdf_export.dart';

/// Exportiert alle Buchungen als CSV (Semikolon-getrennt, Excel-freundlich)
/// oder als PDF-Bericht (Tabelle + Summen).
class ExportScreen extends ConsumerWidget {
  const ExportScreen({super.key});

  static String _field(String s) {
    var v = s;
    // Formel-Injection in Excel/Sheets entschärfen: beginnt ein Wert mit einem
    // Formel-Zeichen, ein Leerzeichen voranstellen -> die App behandelt ihn als
    // Text. Der eigene CSV-Import trimmt das Leerzeichen wieder weg (verlustfrei).
    if (v.isNotEmpty && '=+-@\t\r'.contains(v[0])) {
      v = ' $v';
    }
    if (v.contains(';') || v.contains('"') || v.contains('\n')) {
      return '"${v.replaceAll('"', '""')}"';
    }
    return v;
  }

  String _buildCsv(WidgetRef ref) {
    final txs =
        ref.watch(allTransactionsProvider).asData?.value ??
        const <AppTransaction>[];
    final accounts =
        ref.watch(accountsProvider).asData?.value ?? const <Account>[];
    final accountNames = {for (final a in accounts) a.id: a.name};
    final catNames = ref.watch(categoryNamesProvider);
    final memberNames =
        ref.watch(profileNamesProvider).asData?.value ??
        const <String, String>{};
    final df = DateFormat('dd.MM.yyyy');

    final sorted = [...txs]
      ..sort((a, b) => b.occurredOn.compareTo(a.occurredOn));

    final sb = StringBuffer();
    sb.writeln(
      'Datum;Typ;Betrag;Konto;Zielkonto;Kategorie;Titel;Notiz;Erfasst von',
    );
    for (final t in sorted) {
      final amount = (t.amountCents / 100)
          .toStringAsFixed(2)
          .replaceAll('.', ',');
      final row = [
        df.format(t.occurredOn),
        t.type.label,
        amount,
        accountNames[t.accountId] ?? '',
        t.transferAccountId == null
            ? ''
            : (accountNames[t.transferAccountId] ?? ''),
        t.categoryId == null ? '' : (catNames[t.categoryId] ?? ''),
        t.title,
        t.note,
        memberNames[t.createdBy] ?? '',
      ].map(_field).join(';');
      sb.writeln(row);
    }
    return sb.toString();
  }

  Future<void> _exportPdf(BuildContext context, WidgetRef ref) async {
    final l = AppLocalizations.of(context);
    final txs =
        ref.read(allTransactionsProvider).asData?.value ??
        const <AppTransaction>[];
    final accounts =
        ref.read(accountsProvider).asData?.value ?? const <Account>[];
    final accountNames = {for (final a in accounts) a.id: a.name};
    final catNames = ref.read(categoryNamesProvider);
    final df = DateFormat('dd.MM.yyyy');

    final sorted = [...txs]
      ..sort((a, b) => b.occurredOn.compareTo(a.occurredOn));

    var income = 0;
    var expense = 0;
    final rows = <List<String>>[];
    for (final t in sorted) {
      if (t.type == TransactionType.income) income += t.amountCents;
      if (t.type == TransactionType.expense) expense += t.amountCents;
      final amount = switch (t.type) {
        TransactionType.income => '+${formatCents(t.amountCents)}',
        TransactionType.expense => '-${formatCents(t.amountCents)}',
        TransactionType.transfer => formatCents(t.amountCents),
      };
      rows.add([
        df.format(t.occurredOn),
        t.type.label,
        accountNames[t.accountId] ?? '',
        t.categoryId == null ? '' : (catNames[t.categoryId] ?? ''),
        t.title,
        amount,
      ]);
    }

    try {
      await shareTransactionsPdf(
        heading: l.pdfHeading,
        periodLabel: l.pdfStatusLabel(rows.length, df.format(DateTime.now())),
        rows: rows,
        incomeText: formatCents(income),
        expenseText: formatCents(expense),
        balanceText: formatCents(income - expense),
        filename: 'money-manager-buchungen.pdf',
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l.pdfError(e))));
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final txCount =
        ref.watch(allTransactionsProvider).asData?.value.length ?? 0;
    final csv = _buildCsv(ref);
    final previewLines = const LineSplitter().convert(csv).take(40).join('\n');
    final l = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(l.exportTitle)),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              l.exportSubtitle(txCount),
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: txCount == 0
                        ? null
                        : () async {
                            await Clipboard.setData(ClipboardData(text: csv));
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text(l.csvCopied)),
                              );
                            }
                          },
                    icon: const Icon(Icons.copy_all_outlined),
                    label: Text(l.copyCsv),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: txCount == 0 ? null : () => _share(context, csv),
                    icon: const Icon(Icons.ios_share),
                    label: Text(l.shareCsv),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            FilledButton.tonalIcon(
              onPressed: txCount == 0 ? null : () => _exportPdf(context, ref),
              icon: const Icon(Icons.picture_as_pdf_outlined),
              label: Text(l.sharePdf),
            ),
            const SizedBox(height: 16),
            Text(
              l.previewFirstLines,
              style: Theme.of(context).textTheme.labelMedium,
            ),
            const SizedBox(height: 4),
            Expanded(
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  border: Border.all(color: Theme.of(context).dividerColor),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: SingleChildScrollView(
                  child: SelectableText(
                    previewLines.isEmpty ? l.noData : previewLines,
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 12,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _share(BuildContext context, String csv) async {
    final l = AppLocalizations.of(context);
    try {
      final bytes = Uint8List.fromList(utf8.encode(csv));
      await SharePlus.instance.share(
        ShareParams(
          text: l.exportShareText,
          files: [
            XFile.fromData(
              bytes,
              mimeType: 'text/csv',
              name: 'money-manager-export.csv',
            ),
          ],
        ),
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l.shareFailed(e))));
      }
    }
  }
}
