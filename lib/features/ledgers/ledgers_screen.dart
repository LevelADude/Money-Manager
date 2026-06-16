import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/models/ledger.dart';
import '../profile/profile_providers.dart';
import 'ledger_providers.dart';

/// Startseite: Liste aller Bücher (aller Personen). Jedes Mitglied sieht und
/// bearbeitet alles.
class LedgersScreen extends ConsumerWidget {
  const LedgersScreen({super.key});

  Future<String?> _nameDialog(
    BuildContext context, {
    required String title,
    required String initial,
  }) {
    final controller = TextEditingController(text: initial);
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Name des Buchs'),
          onSubmitted: (v) => Navigator.pop(ctx, v.trim()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Abbrechen'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Future<void> _addLedger(BuildContext context, WidgetRef ref) async {
    final name = await _nameDialog(context, title: 'Neues Buch', initial: '');
    if (name != null && name.isNotEmpty) {
      await ref.read(ledgerRepositoryProvider).createLedger(name: name);
    }
  }

  Future<void> _rename(BuildContext context, WidgetRef ref, Ledger l) async {
    final name =
        await _nameDialog(context, title: 'Buch umbenennen', initial: l.name);
    if (name != null && name.isNotEmpty && name != l.name) {
      await ref
          .read(ledgerRepositoryProvider)
          .renameLedger(id: l.id, name: name);
    }
  }

  Future<void> _delete(BuildContext context, WidgetRef ref, Ledger l) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('„${l.name}" löschen?'),
        content: const Text(
          'Alle Buchungen und Kategorien dieses Buchs werden ebenfalls '
          'gelöscht. Das kann nicht rückgängig gemacht werden.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Abbrechen'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Löschen'),
          ),
        ],
      ),
    );
    if (ok == true) {
      await ref.read(ledgerRepositoryProvider).deleteLedger(l.id);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ledgers = ref.watch(ledgersProvider);
    final memberNames =
        ref.watch(profileNamesProvider).asData?.value ?? const <String, String>{};
    return Scaffold(
      appBar: AppBar(
        title: const Text('Bücher'),
        actions: [
          IconButton(
            tooltip: 'Profil',
            icon: const Icon(Icons.account_circle_outlined),
            onPressed: () => context.go('/profile'),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _addLedger(context, ref),
        icon: const Icon(Icons.add),
        label: const Text('Buch'),
      ),
      body: ledgers.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Fehler: $e')),
        data: (items) {
          if (items.isEmpty) {
            return const Center(
              child: Text('Noch keine Bücher. Lege unten eines an.'),
            );
          }
          return ListView.separated(
            itemCount: items.length,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (_, i) {
              final l = items[i];
              final owner = memberNames[l.ownerId] ?? '';
              final subtitle = [
                l.currency,
                if (owner.isNotEmpty) 'von $owner',
              ].join('  ·  ');
              return ListTile(
                leading: CircleAvatar(
                  child: Icon(
                    l.archived ? Icons.inventory_2_outlined : Icons.menu_book,
                  ),
                ),
                title: Row(
                  children: [
                    Flexible(
                      child: Text(l.name, overflow: TextOverflow.ellipsis),
                    ),
                    if (l.archived) ...[
                      const SizedBox(width: 8),
                      const _ArchivedBadge(),
                    ],
                  ],
                ),
                subtitle: Text(subtitle),
                onTap: () => context.go('/ledger/${l.id}'),
                trailing: PopupMenuButton<String>(
                  onSelected: (value) {
                    switch (value) {
                      case 'rename':
                        _rename(context, ref, l);
                      case 'archive':
                        ref.read(ledgerRepositoryProvider).setArchived(
                              id: l.id,
                              archived: !l.archived,
                            );
                      case 'delete':
                        _delete(context, ref, l);
                    }
                  },
                  itemBuilder: (ctx) => [
                    const PopupMenuItem(
                      value: 'rename',
                      child: ListTile(
                        leading: Icon(Icons.edit_outlined),
                        title: Text('Umbenennen'),
                      ),
                    ),
                    PopupMenuItem(
                      value: 'archive',
                      child: ListTile(
                        leading: Icon(
                          l.archived
                              ? Icons.unarchive_outlined
                              : Icons.archive_outlined,
                        ),
                        title: Text(l.archived ? 'Aktivieren' : 'Archivieren'),
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'delete',
                      child: ListTile(
                        leading: Icon(Icons.delete_outline),
                        title: Text('Löschen'),
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _ArchivedBadge extends StatelessWidget {
  const _ArchivedBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text('Archiviert', style: Theme.of(context).textTheme.labelSmall),
    );
  }
}
