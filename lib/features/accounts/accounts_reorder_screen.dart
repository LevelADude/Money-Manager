import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/account.dart';
import '../../l10n/app_localizations.dart';
import '../../shared/category_icons.dart';
import 'account_providers.dart';

/// Konten per Drag&Drop sortieren. Die Reihenfolge gilt innerhalb der
/// Kontotyp-Gruppen auf dem Konten-Tab.
class AccountsReorderScreen extends ConsumerStatefulWidget {
  const AccountsReorderScreen({super.key});

  @override
  ConsumerState<AccountsReorderScreen> createState() =>
      _AccountsReorderScreenState();
}

class _AccountsReorderScreenState
    extends ConsumerState<AccountsReorderScreen> {
  List<Account>? _local;

  Future<void> _onReorder(int oldIndex, int newIndex) async {
    final list = [..._local!];
    final moved = list.removeAt(oldIndex);
    list.insert(newIndex, moved);
    setState(() => _local = list);
    await ref.read(accountRepositoryProvider).reorder([
      for (var i = 0; i < list.length; i++) (id: list[i].id, sortOrder: i),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final accountsAsync = ref.watch(accountsProvider);
    final l = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l.sortAccounts)),
      body: accountsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text(l.errorWith(e))),
        data: (accounts) {
          // Lokale Kopie mit Server-Stand synchronisieren: bei gleicher Menge
          // die lokale Reihenfolge behalten (sonst springt es nach dem Ziehen),
          // bei geändertem Bestand den Server-Stand übernehmen.
          final cur = _local;
          if (cur == null) {
            _local = [...accounts];
          } else {
            final curIds = cur.map((a) => a.id).toSet();
            final srvIds = accounts.map((a) => a.id).toSet();
            if (curIds.length == srvIds.length && curIds.containsAll(srvIds)) {
              _local = [
                for (final a in cur) accounts.firstWhere((x) => x.id == a.id),
              ];
            } else {
              _local = [...accounts];
            }
          }
          final list = _local!;
          if (list.isEmpty) {
            return Center(child: Text(l.noAccountsShort));
          }
          return ReorderableListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: list.length,
            onReorderItem: _onReorder,
            itemBuilder: (ctx, i) {
              final a = list[i];
              return ListTile(
                key: ValueKey(a.id),
                leading: CircleAvatar(
                  child: Icon(iconForAccountType(accountTypeToDb(a.type))),
                ),
                title: Text(a.name, overflow: TextOverflow.ellipsis),
                subtitle: Text(l.accountType(a.type)),
                trailing: ReorderableDragStartListener(
                  index: i,
                  child: const Icon(Icons.drag_handle),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
