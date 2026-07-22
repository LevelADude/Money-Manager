import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/account.dart';
import '../../data/models/account_group.dart';
import '../../l10n/app_localizations.dart';
import '../../shared/category_icons.dart';
import '../../shared/money_text.dart';
import '../auth/auth_providers.dart';
import 'account_providers.dart';

/// Eigene Konten-Gruppen für Custom-Summen verwalten (anlegen / bearbeiten /
/// löschen). Die Summen selbst erscheinen auf dem Konten-Tab unter dem
/// Gesamtvermögen.
class AccountGroupsScreen extends ConsumerWidget {
  const AccountGroupsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final totals = ref.watch(accountGroupTotalsProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l.customSums)),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showGroupEditor(context, ref),
        icon: const Icon(Icons.add),
        label: Text(l.newGroup),
      ),
      body: totals.isEmpty
          ? Padding(
              padding: const EdgeInsets.all(24),
              child: Center(child: Text(l.noGroupsYet)),
            )
          : ListView(
              padding: const EdgeInsets.symmetric(vertical: 8),
              children: [
                for (final t in totals)
                  ListTile(
                    leading: const CircleAvatar(child: Icon(Icons.functions)),
                    title: Text(t.group.name),
                    subtitle: Text(
                      l.groupAccountCount(t.group.accountIds.length),
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        MoneyText(
                          t.cents,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: t.cents < 0 ? Colors.red.shade700 : null,
                          ),
                        ),
                        PopupMenuButton<String>(
                          onSelected: (v) {
                            if (v == 'edit') {
                              _showGroupEditor(context, ref, existing: t.group);
                            } else if (v == 'delete') {
                              _confirmDelete(context, ref, t.group);
                            }
                          },
                          itemBuilder: (ctx) => [
                            PopupMenuItem(
                              value: 'edit',
                              child: ListTile(
                                leading: const Icon(Icons.edit_outlined),
                                title: Text(l.edit),
                              ),
                            ),
                            PopupMenuItem(
                              value: 'delete',
                              child: ListTile(
                                leading: const Icon(Icons.delete_outline),
                                title: Text(l.delete),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    onTap: () =>
                        _showGroupEditor(context, ref, existing: t.group),
                  ),
              ],
            ),
    );
  }

  Future<void> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    AccountGroup group,
  ) async {
    final l = AppLocalizations.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l.deleteGroup),
        content: Text(group.name),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l.delete),
          ),
        ],
      ),
    );
    if (ok == true) {
      await ref.read(accountGroupRepositoryProvider).remove(group.id);
      ref.invalidate(accountGroupsProvider);
    }
  }

  Future<void> _showGroupEditor(
    BuildContext context,
    WidgetRef ref, {
    AccountGroup? existing,
  }) async {
    final l = AppLocalizations.of(context);
    final me = ref.read(currentUserIdProvider);
    // Nur eigene Konten zur Auswahl (Custom-Summen bündeln die eigenen Konten).
    final myAccounts =
        (ref.read(accountsProvider).value ?? const <Account>[])
            .where((a) => a.ownerId == me)
            .toList();
    final nameCtrl = TextEditingController(text: existing?.name ?? '');
    final selected = <String>{...?existing?.accountIds};

    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: Text(existing == null ? l.newGroup : l.editGroup),
          content: SizedBox(
            width: 360,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameCtrl,
                  autofocus: true,
                  decoration: InputDecoration(labelText: l.groupName),
                ),
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    l.selectAccounts,
                    style: Theme.of(ctx).textTheme.labelMedium,
                  ),
                ),
                Flexible(
                  child: myAccounts.isEmpty
                      ? Padding(
                          padding: const EdgeInsets.all(12),
                          child: Text(l.noAccountsShort),
                        )
                      : ListView(
                          shrinkWrap: true,
                          children: [
                            for (final a in myAccounts)
                              CheckboxListTile(
                                dense: true,
                                value: selected.contains(a.id),
                                onChanged: (v) => setState(() {
                                  if (v == true) {
                                    selected.add(a.id);
                                  } else {
                                    selected.remove(a.id);
                                  }
                                }),
                                secondary: Icon(
                                  iconForAccountType(accountTypeToDb(a.type)),
                                ),
                                title: Text(
                                  a.name,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                          ],
                        ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(l.cancel),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(existing == null ? l.create : l.save),
            ),
          ],
        ),
      ),
    );

    if (saved != true) return;
    final name = nameCtrl.text.trim();
    if (name.isEmpty || selected.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l.groupNeedsAccounts)));
      }
      return;
    }
    final repo = ref.read(accountGroupRepositoryProvider);
    if (existing == null) {
      await repo.create(name, selected.toList());
    } else {
      await repo.update(existing.id, name, selected.toList());
    }
    ref.invalidate(accountGroupsProvider);
  }
}
