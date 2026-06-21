import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../data/models/profile.dart';
import '../../shared/money.dart';
import '../auth/auth_providers.dart';
import '../profile/profile_providers.dart';
import 'admin_providers.dart';

/// Gratis-Limits (Supabase Free): 500 MB Datenbank, 1 GB Datei-Speicher.
const int _kDbLimitBytes = 500 * 1024 * 1024;
const int _kStorageLimitBytes = 1024 * 1024 * 1024;

/// Admin-Bereich: Speichernutzung, E-Mail-Whitelist, Nutzer-/Rollenverwaltung
/// und (geschützte) Wartungsfunktionen.
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

    final isOwner = ref.watch(isOwnerProvider).asData?.value ?? false;
    final emails = ref.watch(allowedEmailsProvider);
    final profiles = ref.watch(allProfilesProvider);
    final myId = ref.watch(supabaseClientProvider).auth.currentUser?.id;
    final df = DateFormat('dd.MM.yyyy');

    return Scaffold(
      appBar: AppBar(title: const Text('Verwaltung')),
      body: ListView(
        children: [
          _sectionTitle(context, 'Speicher'),
          _buildStorage(context, ref),
          const Divider(height: 24),
          ListTile(
            title: _sectionTextStyle(context, 'Freigeschaltete E-Mails'),
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
          _sectionTitle(context, 'Nutzer'),
          profiles.when(
            loading: () => const ListTile(title: LinearProgressIndicator()),
            error: (e, _) => ListTile(title: Text('Fehler: $e')),
            data: (list) => Column(
              children: [
                for (final p in list) _userTile(context, ref, p, myId, df),
              ],
            ),
          ),
          const Divider(height: 24),
          _sectionTitle(context, 'Gefahrenzone'),
          _buildDangerZone(context, ref, isOwner: isOwner),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  // ---- Speicher --------------------------------------------------------

  Widget _buildStorage(BuildContext context, WidgetRef ref) {
    final stats = ref.watch(storageStatsProvider);
    return stats.when(
      loading: () => const Padding(
        padding: EdgeInsets.all(16),
        child: LinearProgressIndicator(),
      ),
      error: (e, _) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Text('Konnte Speichernutzung nicht laden: $e'),
      ),
      data: (s) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
        child: Column(
          children: [
            _usageBar(context, 'Datenbank', s.dbBytes, _kDbLimitBytes),
            const SizedBox(height: 16),
            _usageBar(context, 'Belege / Dateien', s.storageBytes,
                _kStorageLimitBytes),
          ],
        ),
      ),
    );
  }

  Widget _usageBar(BuildContext context, String label, int used, int limit) {
    final theme = Theme.of(context);
    final frac = limit <= 0 ? 0.0 : (used / limit).clamp(0.0, 1.0);
    final warn = frac >= 0.8;
    final color = warn ? theme.colorScheme.error : theme.colorScheme.primary;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: theme.textTheme.bodyMedium),
            Text('${formatBytes(used)} / ${formatBytes(limit)}',
                style: theme.textTheme.bodySmall),
          ],
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: frac,
            minHeight: 8,
            color: color,
          ),
        ),
        const SizedBox(height: 2),
        Align(
          alignment: Alignment.centerRight,
          child: Text('${(frac * 100).toStringAsFixed(0)} %',
              style: theme.textTheme.labelSmall
                  ?.copyWith(color: warn ? color : null)),
        ),
      ],
    );
  }

  // ---- Nutzerzeile -----------------------------------------------------

  Widget _userTile(BuildContext context, WidgetRef ref, Profile p,
      String? myId, DateFormat df) {
    final roleParts = <String>[
      if (p.createdAt != null) 'seit ${df.format(p.createdAt!)}',
      if (p.isOwner) 'Besitzer' else if (p.isAdmin) 'Admin',
      if (p.readOnly) 'nur Lesen',
      if (p.id == myId) 'du',
    ];
    return ListTile(
      leading: CircleAvatar(
        child: Text(p.displayName.isEmpty
            ? '?'
            : p.displayName.substring(0, 1).toUpperCase()),
      ),
      title: Text(p.displayName.isEmpty ? '(ohne Name)' : p.displayName),
      subtitle: Text(roleParts.join('  ·  ')),
      trailing: p.isOwner
          ? const Chip(
              avatar: Icon(Icons.shield_outlined, size: 18),
              label: Text('Besitzer'),
            )
          : PopupMenuButton<String>(
              onSelected: (v) async {
                final repo = ref.read(adminRepositoryProvider);
                switch (v) {
                  case 'admin':
                    await repo.setAdmin(profileId: p.id, value: !p.isAdmin);
                    ref.invalidate(allProfilesProvider);
                  case 'readonly':
                    await repo.setReadOnly(
                        profileId: p.id, value: !p.readOnly);
                    ref.invalidate(allProfilesProvider);
                  case 'delete':
                    if (context.mounted) {
                      await _deleteUser(context, ref, p);
                    }
                }
              },
              itemBuilder: (ctx) => [
                if (p.id != myId)
                  PopupMenuItem(
                    value: 'admin',
                    child: Text(p.isAdmin
                        ? 'Admin-Recht entziehen'
                        : 'Zum Admin machen'),
                  ),
                PopupMenuItem(
                  value: 'readonly',
                  child: Text(p.readOnly
                      ? 'Schreibrechte geben'
                      : 'Auf „nur Lesen" setzen'),
                ),
                if (p.id != myId)
                  const PopupMenuItem(
                    value: 'delete',
                    child: Text('Nutzer löschen'),
                  ),
              ],
            ),
    );
  }

  // ---- Gefahrenzone ----------------------------------------------------

  Widget _buildDangerZone(BuildContext context, WidgetRef ref,
      {required bool isOwner}) {
    final theme = Theme.of(context);
    return Column(
      children: [
        ListTile(
          leading: Icon(Icons.cleaning_services_outlined,
              color: theme.colorScheme.error),
          title: const Text('Datenbank leeren'),
          subtitle: const Text(
              'Löscht ALLE Finanzdaten (Buchungen, Konten, Kategorien, Belege …). '
              'Nutzer, Rollen und Freischaltungen bleiben erhalten.'),
          onTap: () => _runWipe(context, ref),
        ),
        if (isOwner)
          ListTile(
            leading: Icon(Icons.restart_alt, color: theme.colorScheme.error),
            title: const Text('Auf Werkseinstellungen zurücksetzen'),
            subtitle: const Text(
                'Löscht ALLES inkl. aller Login-Konten und Freischaltungen. '
                'Danach ist die Datenbank im Neuzustand – die nächste '
                'Registrierung wird neuer Besitzer. Nur für den Besitzer.'),
            onTap: () => _runFactoryReset(context, ref),
          ),
      ],
    );
  }

  Future<void> _runWipe(BuildContext context, WidgetRef ref) async {
    final ok = await _confirmTyped(
      context,
      title: 'Datenbank leeren?',
      message:
          'Alle Finanzdaten werden unwiderruflich gelöscht. Nutzer bleiben '
          'erhalten. Gib zur Bestätigung LEEREN ein.',
      word: 'LEEREN',
    );
    if (!ok) return;
    try {
      await ref.read(adminRepositoryProvider).wipeData();
      ref.invalidate(storageStatsProvider);
      if (context.mounted) {
        await _infoDialog(
          context,
          'Datenbank geleert',
          'Alle Daten wurden entfernt. Bitte lade die App neu (Strg+R) bzw. '
              'starte sie neu, damit alle Ansichten aktualisiert werden.',
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Fehler: $e')));
      }
    }
  }

  Future<void> _runFactoryReset(BuildContext context, WidgetRef ref) async {
    final ok = await _confirmTyped(
      context,
      title: 'Auf Werkseinstellungen zurücksetzen?',
      message:
          'ALLES wird gelöscht: alle Daten, alle Nutzer und Freischaltungen. '
          'Du wirst danach abgemeldet. Dieser Schritt ist endgültig. Gib zur '
          'Bestätigung ZURÜCKSETZEN ein.',
      word: 'ZURÜCKSETZEN',
    );
    if (!ok) return;
    try {
      await ref.read(adminRepositoryProvider).factoryReset();
      // Sitzung beenden -> Router leitet zum Login (DB ist nun leer).
      await ref.read(supabaseClientProvider).auth.signOut();
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Fehler: $e')));
      }
    }
  }

  /// Bestätigungsdialog mit Tippwort: Knopf erst aktiv, wenn [word] eingegeben.
  Future<bool> _confirmTyped(
    BuildContext context, {
    required String title,
    required String message,
    required String word,
  }) async {
    final ctrl = TextEditingController();
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) {
          final matches = ctrl.text.trim().toUpperCase() == word;
          return AlertDialog(
            title: Text(title),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(message),
                const SizedBox(height: 12),
                TextField(
                  controller: ctrl,
                  autofocus: true,
                  textCapitalization: TextCapitalization.characters,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    labelText: '„$word" eingeben',
                    border: const OutlineInputBorder(),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Abbrechen'),
              ),
              FilledButton(
                onPressed: matches ? () => Navigator.pop(ctx, true) : null,
                style: FilledButton.styleFrom(
                  backgroundColor: Theme.of(ctx).colorScheme.error,
                ),
                child: const Text('Bestätigen'),
              ),
            ],
          );
        },
      ),
    );
    return result ?? false;
  }

  Future<void> _infoDialog(
      BuildContext context, String title, String message) {
    return showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  // ---- kleine Helfer ---------------------------------------------------

  Widget _sectionTitle(BuildContext context, String text) =>
      ListTile(title: _sectionTextStyle(context, text));

  Text _sectionTextStyle(BuildContext context, String text) => Text(
        text,
        style: Theme.of(context)
            .textTheme
            .titleMedium
            ?.copyWith(fontWeight: FontWeight.bold),
      );
}
