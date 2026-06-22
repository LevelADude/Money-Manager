import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../data/models/account.dart';
import '../../data/models/app_transaction.dart';
import '../../data/models/archived_year.dart';
import '../../l10n/app_localizations.dart';
import '../../shared/money.dart';
import '../accounts/account_providers.dart';
import '../profile/profile_providers.dart';
import '../transactions/transaction_providers.dart';
import 'archive_providers.dart';
import 'archive_setup_screen.dart';
import 'archived_year_screen.dart';

/// Archivierung alter Jahre nach GitHub: Jahres-Auswahl + Warnung + Fortschritt
/// (nur Admins) sowie die Liste bereits archivierter Jahre mit read-only-Ansicht
/// und – für Admins – De-Archivieren.
class ArchiveScreen extends ConsumerStatefulWidget {
  const ArchiveScreen({super.key});

  @override
  ConsumerState<ArchiveScreen> createState() => _ArchiveScreenState();
}

class _ArchiveScreenState extends ConsumerState<ArchiveScreen> {
  final Set<int> _selected = {};
  bool _busy = false;
  String _status = '';

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final isAdmin = ref.watch(isAdminProvider).asData?.value ?? false;
    final txs = ref.watch(allTransactionsProvider).asData?.value ??
        const <AppTransaction>[];
    final archivedSet = ref.watch(archivedYearSetProvider);
    final archivedAsync = ref.watch(archivedYearsProvider);
    final configAsync = ref.watch(archiveConfigStatusProvider);
    final df = DateFormat('dd.MM.yyyy');

    // Solange der Verbindungs-Status lädt: Spinner.
    if (configAsync.isLoading && !configAsync.hasValue) {
      return Scaffold(
        appBar: AppBar(title: Text(l.archiveTitle)),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    final config = configAsync.asData?.value;
    final configured = config?.configured ?? false;

    // Noch kein Archiv-Repo verbunden -> Einrichtungs-Hinweis.
    if (!configured) {
      return Scaffold(
        appBar: AppBar(title: Text(l.archiveTitle)),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(l.archiveIntro, style: theme.textTheme.bodyMedium),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(l.archiveNotConfigured,
                        style: theme.textTheme.titleSmall),
                    const SizedBox(height: 8),
                    Text(isAdmin
                        ? l.archiveSetupNeededAdmin
                        : l.archiveSetupNeededUser),
                    if (isAdmin) ...[
                      const SizedBox(height: 12),
                      FilledButton.icon(
                        onPressed: () => Navigator.of(context).push(
                          MaterialPageRoute(
                              builder: (_) => const ArchiveSetupScreen()),
                        ),
                        icon: const Icon(Icons.link),
                        label: Text(l.archiveSetupTitle),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    }

    // Archivierbare Jahre = Jahre mit (sichtbaren) Buchungen, noch nicht
    // archiviert. Aufsteigend (älteste zuerst).
    final counts = <int, int>{};
    for (final t in txs) {
      final y = t.occurredOn.year;
      if (!archivedSet.contains(y)) counts[y] = (counts[y] ?? 0) + 1;
    }
    final years = counts.keys.toList()..sort();

    return Scaffold(
      appBar: AppBar(title: Text(l.archiveTitle)),
      body: ListView(
        children: [
          if (isAdmin && config?.repo != null)
            ListTile(
              dense: true,
              leading: const Icon(Icons.cloud_done_outlined),
              title: Text(l.archiveConnectedTo(config!.repo!)),
              trailing: TextButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(
                      builder: (_) => const ArchiveSetupScreen()),
                ),
                child: Text(l.archiveChange),
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text(l.archiveIntro, style: theme.textTheme.bodyMedium),
          ),
          _warningCard(context),
          if (isAdmin) ...[
            _sectionTitle(context, l.archiveSelectYears),
            if (years.isEmpty)
              ListTile(subtitle: Text(l.archiveNoYears))
            else
              for (final y in years)
                CheckboxListTile(
                  value: _selected.contains(y),
                  onChanged: _busy
                      ? null
                      : (v) => setState(() {
                            if (v == true) {
                              _selected.add(y);
                            } else {
                              _selected.remove(y);
                            }
                          }),
                  title: Text('$y'),
                  subtitle: Text(l.archiveTxCount(counts[y]!)),
                ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
              child: FilledButton.icon(
                onPressed: (_busy || years.isEmpty) ? null : _runArchive,
                icon: const Icon(Icons.archive_outlined),
                label: Text(l.archiveAction),
              ),
            ),
            if (_busy)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const LinearProgressIndicator(),
                    const SizedBox(height: 8),
                    Text(_status, style: theme.textTheme.bodySmall),
                  ],
                ),
              ),
          ],
          const Divider(height: 32),
          _sectionTitle(context, l.archivedSection),
          archivedAsync.when(
            loading: () => const ListTile(title: LinearProgressIndicator()),
            error: (e, _) => ListTile(title: Text(l.archiveError(e))),
            data: (list) => list.isEmpty
                ? ListTile(subtitle: Text(l.archiveNoneArchived))
                : Column(
                    children: [
                      for (final y in list)
                        _archivedTile(context, y, df, isAdmin: isAdmin),
                    ],
                  ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _warningCard(BuildContext context) {
    final theme = Theme.of(context);
    final l = AppLocalizations.of(context);
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.warning_amber_rounded,
              color: theme.colorScheme.onErrorContainer),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              l.archiveWarning,
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.onErrorContainer),
            ),
          ),
        ],
      ),
    );
  }

  Widget _archivedTile(BuildContext context, ArchivedYear y, DateFormat df,
      {required bool isAdmin}) {
    final l = AppLocalizations.of(context);
    final parts = <String>[
      l.archiveTxCount(y.txCount),
      if (y.byteSize > 0) formatBytes(y.byteSize),
      if (y.archivedAt != null) df.format(y.archivedAt!),
    ];
    return ListTile(
      leading: const Icon(Icons.inventory_2_outlined),
      title: Text('${y.year}'),
      subtitle: Text(parts.join('  ·  ')),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextButton(
            onPressed: _busy
                ? null
                : () => Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => ArchivedYearScreen(year: y.year),
                    )),
            child: Text(l.archiveView),
          ),
          if (isAdmin)
            IconButton(
              tooltip: l.archiveRestore,
              icon: const Icon(Icons.unarchive_outlined),
              onPressed: _busy ? null : () => _runRestore(y.year),
            ),
        ],
      ),
    );
  }

  // ---- Aktionen --------------------------------------------------------

  Future<void> _runArchive() async {
    final l = AppLocalizations.of(context);
    if (_selected.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(l.archiveSelectAtLeastOne)));
      return;
    }
    final years = _selected.toList()..sort();
    final ok = await _confirm(
      l.archiveConfirmTitle,
      l.archiveConfirmBody(years.join(', ')),
    );
    if (!ok) return;

    final accounts = ref.read(accountsProvider).asData?.value ?? const <Account>[];
    setState(() => _busy = true);
    try {
      for (final y in years) {
        await ref.read(archiveRepositoryProvider).archiveYear(
              year: y,
              accounts: accounts,
              exportedAtIso: DateTime.now().toUtc().toIso8601String(),
              onProgress: (step) {
                if (mounted) setState(() => _status = '$y · ${_stepLabel(step)}');
              },
            );
      }
      if (!mounted) return;
      setState(() {
        _selected.clear();
        _status = '';
      });
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(years.length == 1
            ? l.archiveDone(years.first)
            : '${l.archivedSection}: ${years.join(', ')}'),
      ));
    } catch (e) {
      if (mounted) {
        setState(() => _status = '');
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(l.archiveError(e))));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _runRestore(int year) async {
    final l = AppLocalizations.of(context);
    final ok = await _confirm(
      l.archiveRestoreConfirmTitle(year),
      l.archiveRestoreConfirmBody,
      confirmLabel: l.archiveRestore,
    );
    if (!ok) return;
    setState(() {
      _busy = true;
      _status = l.archiveRestore;
    });
    try {
      await ref.read(archiveRepositoryProvider).deArchiveYear(year);
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(l.archiveRestoreDone(year))));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(l.archiveError(e))));
      }
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
          _status = '';
        });
      }
    }
  }

  Future<bool> _confirm(String title, String body, {String? confirmLabel}) async {
    final l = AppLocalizations.of(context);
    final r = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(body),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(confirmLabel ?? l.archiveAction),
          ),
        ],
      ),
    );
    return r ?? false;
  }

  String _stepLabel(String step) {
    final l = AppLocalizations.of(context);
    return switch (step) {
      'read' => l.archiveStepRead,
      'receipts' => l.archiveStepReceipts,
      'upload' => l.archiveStepUpload,
      'mark' => l.archiveStepMark,
      'purge' => l.archiveStepPurge,
      _ => '',
    };
  }

  Widget _sectionTitle(BuildContext context, String text) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
        child: Text(
          text,
          style: Theme.of(context)
              .textTheme
              .titleMedium
              ?.copyWith(fontWeight: FontWeight.bold),
        ),
      );
}
