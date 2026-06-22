import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/account.dart';
import '../../data/models/app_transaction.dart';
import '../../data/models/category.dart';
import '../../l10n/app_localizations.dart';
import '../../shared/money.dart';
import '../accounts/account_providers.dart';
import '../categories/category_providers.dart';
import '../transactions/transaction_providers.dart';

/// CSV-Import: liest Buchungen aus eingefügtem CSV (Format wie der Export:
/// Datum;Typ;Betrag;Konto;Zielkonto;Kategorie;Titel;Notiz). Konten/Kategorien
/// werden per Name den vorhandenen zugeordnet.
class CsvImportScreen extends ConsumerStatefulWidget {
  const CsvImportScreen({super.key});

  @override
  ConsumerState<CsvImportScreen> createState() => _CsvImportScreenState();
}

class _CsvImportScreenState extends ConsumerState<CsvImportScreen> {
  final _input = TextEditingController();
  bool _busy = false;
  String _status = '';

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  /// Zerlegt eine CSV-Zeile (Trenner ; oder ,) mit "..."-Quoting.
  List<String> _splitLine(String line, String delim) {
    final out = <String>[];
    final sb = StringBuffer();
    var inQuotes = false;
    for (var i = 0; i < line.length; i++) {
      final c = line[i];
      if (c == '"') {
        if (inQuotes && i + 1 < line.length && line[i + 1] == '"') {
          sb.write('"');
          i++;
        } else {
          inQuotes = !inQuotes;
        }
      } else if (c == delim && !inQuotes) {
        out.add(sb.toString());
        sb.clear();
      } else {
        sb.write(c);
      }
    }
    out.add(sb.toString());
    return out;
  }

  DateTime? _parseDate(String s) {
    s = s.trim();
    // dd.MM.yyyy
    final de = RegExp(r'^(\d{1,2})\.(\d{1,2})\.(\d{4})$').firstMatch(s);
    if (de != null) {
      return DateTime(
        int.parse(de.group(3)!),
        int.parse(de.group(2)!),
        int.parse(de.group(1)!),
      );
    }
    // yyyy-MM-dd
    return DateTime.tryParse(s);
  }

  TransactionType _parseType(String s) {
    final t = s.trim().toLowerCase();
    if (t.startsWith('einnahme') || t == 'income') {
      return TransactionType.income;
    }
    if (t.startsWith('übertrag') ||
        t.startsWith('uebertrag') ||
        t == 'transfer') {
      return TransactionType.transfer;
    }
    return TransactionType.expense;
  }

  Future<void> _import() async {
    final l = AppLocalizations.of(context);
    final text = _input.text.trim();
    if (text.isEmpty) return;
    setState(() {
      _busy = true;
      _status = l.importing;
    });
    try {
      final accounts =
          ref.read(accountsProvider).asData?.value ?? const <Account>[];
      final cats =
          ref.read(categoriesProvider).asData?.value ?? const <Category>[];
      final accByName = {for (final a in accounts) a.name.toLowerCase(): a.id};
      final catByName = {for (final c in cats) c.name.toLowerCase(): c.id};

      final lines = const LineSplitter()
          .convert(text)
          .where((l) => l.trim().isNotEmpty)
          .toList();
      if (lines.isEmpty) {
        setState(() => _status = l.noLinesDetected);
        return;
      }
      final delim = lines.first.contains(';') ? ';' : ',';
      final header = _splitLine(
        lines.first,
        delim,
      ).map((h) => h.trim().toLowerCase()).toList();
      int col(String name) => header.indexWhere((h) => h.contains(name));
      final iDate = col('datum');
      final iType = col('typ');
      final iAmount = col('betrag');
      final iAccount = col('konto');
      final iTarget = header.indexWhere((h) => h.contains('zielkonto'));
      final iCat = col('kategorie');
      final iTitle = col('titel');
      final iNote = col('notiz');
      if (iDate < 0 || iAmount < 0 || iAccount < 0) {
        setState(() => _status = l.csvHeaderNeeds);
        return;
      }

      final repo = ref.read(transactionRepositoryProvider);
      var imported = 0;
      var skipped = 0;
      for (final line in lines.skip(1)) {
        final f = _splitLine(line, delim);
        String at(int i) => (i >= 0 && i < f.length) ? f[i].trim() : '';
        final date = _parseDate(at(iDate));
        final cents = parseToCents(at(iAmount));
        // "Konto" kann beim Zielkonto stehen; nimm Zielkonto-Spalte separat.
        final accId = accByName[at(iAccount).toLowerCase()];
        if (date == null || cents == null || cents <= 0 || accId == null) {
          skipped++;
          continue;
        }
        final type = iType < 0
            ? TransactionType.expense
            : _parseType(at(iType));
        String? targetId;
        if (type == TransactionType.transfer) {
          targetId = accByName[at(iTarget).toLowerCase()];
          if (targetId == null) {
            skipped++;
            continue;
          }
        }
        await repo.addTransaction(
          accountId: accId,
          type: type,
          amountCents: cents,
          occurredOn: date,
          title: at(iTitle),
          note: at(iNote),
          categoryId: type == TransactionType.transfer
              ? null
              : catByName[at(iCat).toLowerCase()],
          transferAccountId: targetId,
        );
        imported++;
      }
      ref.invalidate(allTransactionsProvider);
      setState(() => _status = l.importResult(imported, skipped));
    } catch (e) {
      setState(() => _status = l.errorWith(e));
    } finally {
      setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l.moreImport)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(l.csvImportIntro),
          const SizedBox(height: 12),
          TextField(
            controller: _input,
            maxLines: 10,
            decoration: const InputDecoration(
              hintText:
                  'Datum;Typ;Betrag;Konto;Zielkonto;Kategorie;Titel;Notiz\n'
                  '01.06.2026;Ausgabe;12,50;Bargeld;;Lebensmittel;Aldi;',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: _busy ? null : _import,
            icon: const Icon(Icons.file_download_outlined),
            label: Text(l.importAction),
          ),
          if (_busy)
            const Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: CircularProgressIndicator()),
            ),
          if (_status.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(
                _status,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
        ],
      ),
    );
  }
}
