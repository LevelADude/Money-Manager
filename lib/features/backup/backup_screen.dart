import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../l10n/app_localizations.dart';
import '../auth/auth_providers.dart';

/// Komplettes Backup aller Daten als JSON (Export) sowie Wiederherstellung
/// (Import) – z. B. zur Sicherung oder zum Umzug in ein frisches Projekt.
class BackupScreen extends ConsumerStatefulWidget {
  const BackupScreen({super.key});

  @override
  ConsumerState<BackupScreen> createState() => _BackupScreenState();
}

class _BackupScreenState extends ConsumerState<BackupScreen> {
  // Reihenfolge wegen Fremdschlüssel-Abhängigkeiten (Eltern zuerst).
  static const _tables = [
    'categories',
    'accounts',
    'transactions',
    'transaction_splits',
    'budgets',
    'recurring_rules',
    'savings_goals',
    'transaction_templates',
  ];

  bool _busy = false;
  String _status = '';

  Future<String> _buildBackup() async {
    final client = ref.read(supabaseClientProvider);
    final tables = <String, dynamic>{};
    for (final t in _tables) {
      try {
        tables[t] = await client.from(t).select();
      } catch (_) {
        // Tabelle existiert evtl. nicht – überspringen.
      }
    }
    return const JsonEncoder.withIndent('  ').convert({
      'app': 'money-manager',
      'version': 1,
      'tables': tables,
    });
  }

  Future<void> _export() async {
    final l = AppLocalizations.of(context);
    setState(() {
      _busy = true;
      _status = l.exporting;
    });
    try {
      final json = await _buildBackup();
      final bytes = Uint8List.fromList(utf8.encode(json));
      await SharePlus.instance.share(
        ShareParams(
          text: l.backupShareText,
          files: [
            XFile.fromData(bytes,
                mimeType: 'application/json',
                name: 'money-manager-backup.json'),
          ],
        ),
      );
      setState(() => _status = l.backupCreated);
    } catch (e) {
      setState(() => _status = l.exportError(e));
    } finally {
      setState(() => _busy = false);
    }
  }

  Future<void> _copy() async {
    final l = AppLocalizations.of(context);
    setState(() => _busy = true);
    try {
      final json = await _buildBackup();
      await Clipboard.setData(ClipboardData(text: json));
      setState(() => _status = l.backupCopied);
    } catch (e) {
      setState(() => _status = l.errorWith(e));
    } finally {
      setState(() => _busy = false);
    }
  }

  Future<void> _import() async {
    final l = AppLocalizations.of(context);
    final controller = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l.importBackup),
        content: SizedBox(
          width: 500,
          child: TextField(
            controller: controller,
            maxLines: 8,
            decoration: InputDecoration(
              hintText: l.pasteBackupJson,
              border: const OutlineInputBorder(),
            ),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(l.cancel)),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(l.importAction)),
        ],
      ),
    );
    if (ok != true) return;

    setState(() {
      _busy = true;
      _status = l.importing;
    });
    try {
      final data = jsonDecode(controller.text) as Map<String, dynamic>;
      final tables = (data['tables'] as Map?) ?? {};
      final client = ref.read(supabaseClientProvider);
      final uid = client.auth.currentUser?.id;
      var count = 0;
      for (final t in _tables) {
        final rows = (tables[t] as List?) ?? const [];
        if (rows.isEmpty) continue;
        final mapped = [
          for (final r in rows)
            {
              ...Map<String, dynamic>.from(r as Map),
              // Besitzer/Ersteller auf den aktuellen Nutzer umbiegen.
              if ((r).containsKey('owner_id')) 'owner_id': uid,
              if ((r).containsKey('created_by')) 'created_by': uid,
            },
        ];
        await client.from(t).upsert(mapped);
        count += mapped.length;
      }
      setState(() => _status = l.recordsImported(count));
    } catch (e) {
      setState(() => _status = l.importError(e));
    } finally {
      setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l.moreBackup)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(l.backupSection, style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 4),
          Text(l.backupDesc),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: _busy ? null : _export,
                  icon: const Icon(Icons.ios_share),
                  label: Text(l.shareSave),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _busy ? null : _copy,
                  icon: const Icon(Icons.copy_all_outlined),
                  label: Text(l.copyAction),
                ),
              ),
            ],
          ),
          const Divider(height: 40),
          Text(l.restoreSection,
              style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 4),
          Text(l.restoreDesc),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: _busy ? null : _import,
            icon: const Icon(Icons.settings_backup_restore),
            label: Text(l.importBackup),
          ),
          const SizedBox(height: 24),
          if (_busy) const Center(child: CircularProgressIndicator()),
          if (_status.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(_status,
                  style: Theme.of(context).textTheme.bodyMedium),
            ),
        ],
      ),
    );
  }
}
