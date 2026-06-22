import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../data/models/app_transaction.dart';
import '../../l10n/app_localizations.dart';
import '../../shared/money.dart';
import 'archive_providers.dart';

/// Schreibgeschützte Ansicht eines archivierten Jahres. Lädt die Buchungen
/// (entschlüsselt) von GitHub über den Proxy – strikt getrennt vom
/// bearbeitbaren Datenstrom. Kein Bearbeiten/Löschen.
class ArchivedYearScreen extends ConsumerWidget {
  const ArchivedYearScreen({super.key, required this.year});

  final int year;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final async = ref.watch(archivedYearTransactionsProvider(year));
    final df = DateFormat('dd.MM.yyyy');

    return Scaffold(
      appBar: AppBar(title: Text(l.archiveYearViewTitle(year))),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            color: theme.colorScheme.surfaceContainerHighest,
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                const Icon(Icons.lock_outline, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(l.archiveReadOnlyNote,
                      style: theme.textTheme.bodySmall),
                ),
              ],
            ),
          ),
          Expanded(
            child: async.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(l.archiveError(e)),
                ),
              ),
              data: (txs) => txs.isEmpty
                  ? Center(child: Text(l.archiveEmptyYear))
                  : ListView.separated(
                      itemCount: txs.length,
                      separatorBuilder: (_, _) => const Divider(height: 1),
                      itemBuilder: (c, i) => _tile(context, txs[i], df),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _tile(BuildContext context, AppTransaction t, DateFormat df) {
    final theme = Theme.of(context);
    final (sign, color) = switch (t.type) {
      TransactionType.income => ('+', Colors.green),
      TransactionType.expense => ('-', theme.colorScheme.error),
      TransactionType.transfer => ('', theme.colorScheme.onSurfaceVariant),
    };
    return ListTile(
      dense: true,
      title: Text(t.title.isEmpty ? '—' : t.title),
      subtitle: Text(df.format(t.occurredOn)),
      trailing: Text(
        '$sign${formatCents(t.amountCents)}',
        style: theme.textTheme.bodyMedium
            ?.copyWith(color: color, fontWeight: FontWeight.w600),
      ),
    );
  }
}
