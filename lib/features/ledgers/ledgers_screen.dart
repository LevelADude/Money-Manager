import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../auth/auth_providers.dart';
import 'ledger_providers.dart';

/// Startseite: Liste aller Bücher (aller Personen). Jedes Mitglied sieht und
/// bearbeitet alles.
class LedgersScreen extends ConsumerWidget {
  const LedgersScreen({super.key});

  Future<void> _addLedgerDialog(BuildContext context, WidgetRef ref) async {
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Neues Buch'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Name des Buchs'),
          onSubmitted: (v) => Navigator.pop(ctx, v),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Abbrechen'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, controller.text),
            child: const Text('Anlegen'),
          ),
        ],
      ),
    );
    if (name != null && name.trim().isNotEmpty) {
      await ref.read(ledgerRepositoryProvider).createLedger(name: name.trim());
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ledgers = ref.watch(ledgersProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Bücher'),
        actions: [
          IconButton(
            tooltip: 'Abmelden',
            icon: const Icon(Icons.logout),
            onPressed: () => ref.read(authRepositoryProvider).signOut(),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _addLedgerDialog(context, ref),
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
              return ListTile(
                leading: const CircleAvatar(child: Icon(Icons.menu_book)),
                title: Text(l.name),
                subtitle: Text(l.currency),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.go('/ledger/${l.id}'),
              );
            },
          );
        },
      ),
    );
  }
}
