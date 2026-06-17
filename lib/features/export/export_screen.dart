import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';

import '../../data/models/account.dart';
import '../../data/models/app_transaction.dart';
import '../accounts/account_providers.dart';
import '../categories/category_providers.dart';
import '../profile/profile_providers.dart';
import '../transactions/transaction_providers.dart';

/// Exportiert alle Buchungen als CSV (Semikolon-getrennt, Excel-freundlich).
class ExportScreen extends ConsumerWidget {
  const ExportScreen({super.key});

  static String _field(String s) {
    if (s.contains(';') || s.contains('"') || s.contains('\n')) {
      return '"${s.replaceAll('"', '""')}"';
    }
    return s;
  }

  String _buildCsv(WidgetRef ref) {
    final txs = ref.watch(allTransactionsProvider).asData?.value ??
        const <AppTransaction>[];
    final accounts =
        ref.watch(accountsProvider).asData?.value ?? const <Account>[];
    final accountNames = {for (final a in accounts) a.id: a.name};
    final catNames = ref.watch(categoryNamesProvider);
    final memberNames =
        ref.watch(profileNamesProvider).asData?.value ?? const <String, String>{};
    final df = DateFormat('dd.MM.yyyy');

    final sorted = [...txs]
      ..sort((a, b) => b.occurredOn.compareTo(a.occurredOn));

    final sb = StringBuffer();
    sb.writeln(
        'Datum;Typ;Betrag;Konto;Zielkonto;Kategorie;Titel;Notiz;Erfasst von');
    for (final t in sorted) {
      final amount =
          (t.amountCents / 100).toStringAsFixed(2).replaceAll('.', ',');
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

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final txCount =
        ref.watch(allTransactionsProvider).asData?.value.length ?? 0;
    final csv = _buildCsv(ref);
    final previewLines = const LineSplitter().convert(csv).take(40).join('\n');

    return Scaffold(
      appBar: AppBar(title: const Text('Export (CSV)')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('$txCount Buchungen · Semikolon-getrennt (Excel/Sheets)',
                style: Theme.of(context).textTheme.bodyMedium),
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
                                const SnackBar(
                                    content: Text('CSV in Zwischenablage kopiert')),
                              );
                            }
                          },
                    icon: const Icon(Icons.copy_all_outlined),
                    label: const Text('Kopieren'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: txCount == 0
                        ? null
                        : () => _share(context, csv),
                    icon: const Icon(Icons.ios_share),
                    label: const Text('Teilen / Speichern'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text('Vorschau (erste Zeilen):',
                style: Theme.of(context).textTheme.labelMedium),
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
                    previewLines.isEmpty ? 'Keine Daten.' : previewLines,
                    style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
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
    try {
      final bytes = Uint8List.fromList(utf8.encode(csv));
      await SharePlus.instance.share(
        ShareParams(
          text: 'Money-Manager Export',
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Teilen nicht möglich ($e). Nutze „Kopieren".')),
        );
      }
    }
  }
}
