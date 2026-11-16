import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/archive_repository.dart';
import '../../l10n/app_localizations.dart';
import 'archive_providers.dart';
import '../../core/theme.dart';
import '../../shared/bento.dart';

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
  bool _saving = false;
  bool _disconnecting = false;

  bool get _busy => _saving || _disconnecting;

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
    final status = statusAsync.value;

    // Repo-Feld einmalig mit dem gespeicherten Wert vorbelegen.
    if (!_prefilled && status != null) {
      _prefilled = true;
      _repo.text = status.repo ?? '';
    }
    final hasKey = status?.hasKey ?? false;

    final connectedRepo = status != null && status.configured
        ? status.repo ?? ''
        : null;
    final connected = connectedRepo != null;
    final theme = Theme.of(context);

    // Ladekreis im jeweiligen Knopf statt eines Balkens unter allem.
    Widget busyIcon(bool active, IconData icon) => active
        ? const SizedBox.square(
            dimension: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
        : Icon(icon);

    return Scaffold(
      appBar: AppBar(title: Text(l.archiveSetupTitle)),
      body: ListView(
        padding: BentoListView.paddingOf(context),
        children: [
          // Hinweis-Kachel; ist das Archiv verbunden, steht der Status
          // darüber und der Kreis zeigt ein Häkchen in Einnahmenfarbe.
          BentoTile(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                BentoGlyph(
                  tint: connected ? AppColors.of(context).income : null,
                  child: Icon(
                    connected
                        ? Icons.check_circle_outline
                        : Icons.inventory_2_outlined,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (connectedRepo != null) ...[
                        Text(
                          l.archiveConnectedTo(connectedRepo),
                          style: theme.textTheme.bodyLarge!.copyWith(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
                      ],
                      Text(
                        l.archiveSetupIntro,
                        style: connected
                            ? Bento.sub(context).copyWith(fontSize: 13)
                            : theme.textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: Bento.gap * 2),
          TextField(
            controller: _repo,
            enabled: !_busy,
            decoration: InputDecoration(
              labelText: l.archiveRepoLabel,
              hintText: 'owner/money-manager-archive',
            ),
          ),
          const SizedBox(height: Bento.gap),
          TextField(
            controller: _token,
            enabled: !_busy,
            obscureText: true,
            decoration: InputDecoration(
              labelText: l.archiveTokenLabel,
              helperText: hasKey ? l.archiveTokenKeepHint : null,
              helperMaxLines: 2,
            ),
          ),
          const SizedBox(height: Bento.gap * 2),
          FilledButton.icon(
            onPressed: _busy ? null : _save,
            icon: busyIcon(_saving, Icons.link),
            label: Text(hasKey ? l.archiveSave : l.archiveConnect),
          ),
          if (connected) ...[
            const SizedBox(height: Bento.gap),
            OutlinedButton.icon(
              onPressed: _busy ? null : _disconnect,
              icon: busyIcon(_disconnecting, Icons.link_off),
              label: Text(l.archiveDisconnect),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _save() async {
    final l = AppLocalizations.of(context);
    final repo = _repo.text.trim();
    final token = _token.text.trim();
    final hasKey = ref.read(archiveConfigStatusProvider).value?.hasKey ?? false;

    // Erst-Einrichtung braucht Repo + Token; spätere Änderung braucht nur Repo.
    if (repo.isEmpty || (!hasKey && token.isEmpty)) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l.archiveRepoTokenRequired)));
      return;
    }

    setState(() => _saving = true);
    try {
      // Beim ersten Einrichten einen Schlüssel erzeugen und einmalig anzeigen.
      final newKey = hasKey ? null : ArchiveRepository.generateEncKey();
      await ref
          .read(archiveRepositoryProvider)
          .setArchiveConfig(
            repo: repo,
            token: token.isEmpty ? null : token,
            encKey: newKey,
          );
      ref.invalidate(archiveConfigStatusProvider);
      _token.clear();
      if (!mounted) return;
      if (newKey != null) await _showKeyBackup(newKey);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l.archiveConfigSaved)));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l.archiveError(e))));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
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
          FilledButton(onPressed: () => Navigator.pop(ctx), child: Text(l.ok)),
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
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l.archiveDisconnect),
          ),
        ],
      ),
    );
    if (ok != true) return;
    setState(() => _disconnecting = true);
    try {
      await ref.read(archiveRepositoryProvider).clearArchiveConfig();
      ref.invalidate(archiveConfigStatusProvider);
      _repo.clear();
      _token.clear();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l.archiveError(e))));
      }
    } finally {
      if (mounted) setState(() => _disconnecting = false);
    }
  }
}
