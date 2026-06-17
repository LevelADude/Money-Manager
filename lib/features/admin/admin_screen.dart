import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../data/models/profile.dart';
import '../auth/auth_providers.dart';
import '../profile/profile_providers.dart';
import 'admin_providers.dart';

/// Admin-Bereich: E-Mail-Whitelist verwalten + Nutzerübersicht/-verwaltung.
class AdminScreen extends ConsumerWidget {
  const AdminScreen({super.key});

  Future<void> _addEmail(BuildContext context, WidgetRef ref) async {
    final controller = TextEditingController();
    final email = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('E-Mail freischalten'),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: TextInputType.emailAddress,
          decoration: const InputDecoration(labelText: 'E-Mail-Adresse'),
          onSubmitted: (v) => Navigator.pop(ctx, v),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Abbrechen'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, controller.text),
            child: const Text('Freischalten'),
          ),
        ],
      ),
    );
    if (email == null || !email.trim().contains('@')) return;
    try {
      await ref.read(adminRepositoryProvider).addAllowedEmail(email);
      ref.invalidate(allowedEmailsProvider);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Fehler: $e')));
      }
    }
  }

  Future<void> _deleteUser(
      BuildContext context, WidgetRef ref, Profile p) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Nutzer „${p.displayName}" löschen?'),
        content: const Text(
          'Das Konto wird dauerhaft entfernt. Erfasste Buchungen/Konten bleiben '
          'erhalten (ohne Zuordnung). Das kann nicht rückgängig gemacht werden.',
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
    if (ok != true) return;
    try {
      await ref.read(adminRepositoryProvider).deleteUser(p.id);
      ref.invalidate(allProfilesProvider);
      ref.invalidate(profileNamesProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Nutzer gelöscht')));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Fehler: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isAdmin = ref.watch(isAdminProvider).asData?.value ?? false;
    if (!isAdmin) {
      return Scaffold(
        appBar: AppBar(title: const Text('Verwaltung')),
        body: const Center(child: Text('Kein Zugriff (nur für Admins).')),
      );
    }

    final emails = ref.watch(allowedEmailsProvider);
    final profiles = ref.watch(allProfilesProvider);
    final myId = ref.watch(supabaseClientProvider).auth.currentUser?.id;
    final df = DateFormat('dd.MM.yyyy');

    return Scaffold(
      appBar: AppBar(title: const Text('Verwaltung')),
      body: ListView(
        children: [
          ListTile(
            title: Text('Freigeschaltete E-Mails',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.bold)),
            trailing: FilledButton.tonalIcon(
              onPressed: () => _addEmail(context, ref),
              icon: const Icon(Icons.add),
              label: const Text('E-Mail'),
            ),
          ),
          emails.when(
            loading: () => const ListTile(title: LinearProgressIndicator()),
            error: (e, _) => ListTile(title: Text('Fehler: $e')),
            data: (list) => list.isEmpty
                ? const ListTile(
                    subtitle: Text(
                        'Noch keine. Nur freigeschaltete E-Mails können sich '
                        'registrieren (außer dem ersten Konto).'))
                : Column(
                    children: [
                      for (final email in list)
                        ListTile(
                          dense: true,
                          leading: const Icon(Icons.mark_email_read_outlined),
                          title: Text(email),
                          trailing: IconButton(
                            icon: const Icon(Icons.delete_outline),
                            onPressed: () async {
                              await ref
                                  .read(adminRepositoryProvider)
                                  .removeAllowedEmail(email);
                              ref.invalidate(allowedEmailsProvider);
                            },
                          ),
                        ),
                    ],
                  ),
          ),
          const Divider(height: 24),
          ListTile(
            title: Text('Nutzer',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.bold)),
          ),
          profiles.when(
            loading: () => const ListTile(title: LinearProgressIndicator()),
            error: (e, _) => ListTile(title: Text('Fehler: $e')),
            data: (list) => Column(
              children: [
                for (final p in list)
                  ListTile(
                    leading: CircleAvatar(
                      child: Text(p.displayName.isEmpty
                          ? '?'
                          : p.displayName.substring(0, 1).toUpperCase()),
                    ),
                    title: Text(
                        p.displayName.isEmpty ? '(ohne Name)' : p.displayName),
                    subtitle: Text([
                      if (p.createdAt != null) 'seit ${df.format(p.createdAt!)}',
                      if (p.isAdmin) 'Admin',
                      if (p.id == myId) 'du',
                    ].join('  ·  ')),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('Admin'),
                        Switch(
                          value: p.isAdmin,
                          onChanged: p.id == myId
                              ? null // eigene Admin-Rechte nicht entziehen
                              : (v) async {
                                  await ref
                                      .read(adminRepositoryProvider)
                                      .setAdmin(profileId: p.id, value: v);
                                  ref.invalidate(allProfilesProvider);
                                },
                        ),
                        IconButton(
                          tooltip: 'Löschen',
                          icon: const Icon(Icons.delete_outline),
                          onPressed: p.id == myId
                              ? null
                              : () => _deleteUser(context, ref, p),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
