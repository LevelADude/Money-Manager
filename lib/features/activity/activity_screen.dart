import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart' hide TextDirection;

import '../../shared/money.dart';
import '../profile/profile_providers.dart';
import '../transactions/transaction_providers.dart';

/// Aktivitäts-Feed: wer hat welche Buchung wann angelegt/geändert/gelöscht.
class ActivityScreen extends ConsumerWidget {
  const ActivityScreen({super.key});

  IconData _icon(String action) => switch (action) {
        'insert' => Icons.add_circle_outline,
        'delete' => Icons.delete_outline,
        'restore' => Icons.restore,
        'purge' => Icons.delete_forever,
        _ => Icons.edit_outlined,
      };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(recentActivityProvider);
    final names =
        ref.watch(profileNamesProvider).asData?.value ?? const <String, String>{};
    final df = DateFormat('dd.MM.yyyy HH:mm');

    return Scaffold(
      appBar: AppBar(title: const Text('Aktivität')),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(recentActivityProvider),
        child: async.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => ListView(children: [
            const SizedBox(height: 80),
            Center(child: Text('Fehler: $e')),
          ]),
          data: (items) {
            if (items.isEmpty) {
              return ListView(children: const [
                SizedBox(height: 80),
                Center(child: Text('Noch keine Aktivität.')),
              ]);
            }
            return ListView.separated(
              itemCount: items.length,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (ctx, i) {
                final e = items[i];
                final title = (e.data?['title'] as String?)?.trim();
                final amount = (e.data?['amount_cents'] as num?)?.toInt();
                final who = names[e.actor] ?? 'Unbekannt';
                return ListTile(
                  leading: Icon(_icon(e.action)),
                  title: Text(title == null || title.isEmpty
                      ? '${e.actionLabel}: Buchung'
                      : '${e.actionLabel}: $title'),
                  subtitle: Text('$who · ${df.format(e.at.toLocal())}'),
                  trailing: amount == null
                      ? null
                      : Text(formatCents(amount),
                          style: const TextStyle(fontWeight: FontWeight.bold)),
                  onTap: e.action == 'purge' || e.rowId == null
                      ? null
                      : () => context.go('/transactions/${e.rowId}'),
                );
              },
            );
          },
        ),
      ),
    );
  }
}
