import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/archive_repository.dart';
import '../../l10n/app_localizations.dart';
import 'archive_providers.dart';

/// Richtet das private GitHub-Archiv-Repo ein: Repo-URL + Token eingeben,
/// Schlüssel wird erzeugt und (einmalig) zum Sichern angezeigt. Token & Schlüssel
/// landen serverseitig in Supabase (RPC), nie im Client.
class ArchiveSetupScreen extends ConsumerStatefulWidget {
  const ArchiveSetupScreen({super.key});

  @override
  ConsumerState<ArchiveSetupScreen> createState() => _ArchiveSetupScreenState();
}

class _ArchiveSetupScreenState extends ConsumerState<ArchiveSetupScreen> {
  final _repo = TextEditingController();
  final _token = TextEditingController();
  bool _prefilled = false;
  bool _busy = false;

  @override
  void dispose() {
    _repo.dispose();
    _token.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final statusAsync = ref.watch(archiveConfigStatusProvider);
    final status = statusAsync.asData?.value;

    // Repo-Feld einmalig mit dem gespeicherten Wert vorbelegen.
    if (!_prefilled && status != null) {
      _prefilled = true;
      _repo.text = status.repo ?? '';
    }
    final hasKey = status?.hasKey ?? false;

    return Scaffold(
      appBar: AppBar(title: Text(l.archiveSetupTitle)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (status != null && status.configured)
            Card(
              child: ListTile(
                leading: const Icon(Icons.check_circle_outline),
                title: Text(l.archiveConnectedTo(status.repo ?? '')),
              ),
            ),
          const SizedBox(height: 8),
          Text(l.archiveSetupIntro,
              style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: 16),
          TextField(
            controller: _repo,
            enabled: !_busy,
            decoration: InputDecoration(
              labelText: l.archiveRepoLabel,
              border: const OutlineInputBorder(),
              hintText: 'owner/money-manager-archive',
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _token,
            enabled: !_busy,
            obscureText: true,
            decoration: InputDecoration(
              labelText: l.archiveTokenLabel,
              border: const OutlineInputBorder(),
              helperText: hasKey ? l.archiveTokenKeepHint : null,
              helperMaxLines: 2,
            ),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _busy ? null : _save,
            icon: const Icon(Icons.link),
            label: Text(hasKey ? l.archiveSave : l.archiveConnect),
          ),
          if (status != null && status.configured) ...[
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: _busy ? null : _disconnect,
              icon: const Icon(Icons.link_off),
              label: Text(l.archiveDisconnect),
            ),
          ],
          if (_busy)
            const Padding(
              padding: EdgeInsets.only(top: 16),
              child: LinearProgressIndicator(),
            ),
        ],
      ),
    );
  }

  Future<void> _save() async {
    final l = AppLocalizations.of(context);
    final repo = _repo.text.trim();
    final token = _token.text.trim();
    final hasKey = ref.read(archiveConfigStatusProvider).asData?.value.hasKey ?? false;

    // Erst-Einrichtung braucht Repo + Token; spätere Änderung braucht nur Repo.
    if (repo.isEmpty || (!hasKey && token.isEmpty)) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(l.archiveRepoTokenRequired)));
      return;
    }

    setState(() => _busy = true);
    try {
      // Beim ersten Einrichten einen Schlüssel erzeugen und einmalig anzeigen.
      final newKey = hasKey ? null : ArchiveRepository.generateEncKey();
      await ref.read(archiveRepositoryProvider).setArchiveConfig(
            repo: repo,
            token: token.isEmpty ? null : token,
            encKey: newKey,
          );
      ref.invalidate(archiveConfigStatusProvider);
      _token.clear();
      if (!mounted) return;
      if (newKey != null) await _showKeyBackup(newKey);
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(l.archiveConfigSaved)));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(l.archiveError(e))));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _showKeyBackup(String key) async {
    final l = AppLocalizations.of(context);
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: Text(l.archiveKeyBackupTitle),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(l.archiveKeyBackupBody),
            const SizedBox(height: 12),
            SelectableText(
              key,
              style: const TextStyle(fontFamily: 'monospace'),
            ),
          ],
        ),
        actions: [
          TextButton.icon(
            onPressed: () => Clipboard.setData(ClipboardData(text: key)),
            icon: const Icon(Icons.copy_all_outlined),
            label: Text(l.copyAction),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l.ok),
          ),
        ],
      ),
    );
  }

  Future<void> _disconnect() async {
    final l = AppLocalizations.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l.archiveDisconnectConfirmTitle),
        content: Text(l.archiveDisconnectConfirmBody),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false), child: Text(l.cancel)),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(l.archiveDisconnect)),
        ],
      ),
    );
    if (ok != true) return;
    setState(() => _busy = true);
    try {
      await ref.read(archiveRepositoryProvider).clearArchiveConfig();
      ref.invalidate(archiveConfigStatusProvider);
      _repo.clear();
      _token.clear();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(l.archiveError(e))));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}
