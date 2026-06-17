import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../config/app_config.dart';
import '../auth/auth_providers.dart';
import 'profile_providers.dart';

/// Eigenes Profil ansehen/bearbeiten (Anzeigename) + Abmelden.
class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  final _name = TextEditingController();
  bool _loaded = false;
  bool _saving = false;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await ref
          .read(profileRepositoryProvider)
          .updateMyDisplayName(_name.text.trim());
      ref.invalidate(profileNamesProvider);
      ref.invalidate(myDisplayNameProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profil gespeichert')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Fehler: $e')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final email =
        ref.watch(supabaseClientProvider).auth.currentUser?.email ?? '';
    // Anzeigename einmalig in den Controller laden.
    ref.watch(myDisplayNameProvider).whenData((value) {
      if (!_loaded) {
        _name.text = value;
        _loaded = true;
      }
    });

    return Scaffold(
      appBar: AppBar(title: const Text('Profil')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ListTile(
              leading: const Icon(Icons.email_outlined),
              title: const Text('E-Mail'),
              subtitle: Text(email.isEmpty ? '—' : email),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _name,
              decoration: const InputDecoration(
                labelText: 'Anzeigename',
                prefixIcon: Icon(Icons.person_outline),
              ),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _saving ? null : _save,
              icon: _saving
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.check),
              label: const Text('Speichern'),
            ),
            const SizedBox(height: 24),
            OutlinedButton.icon(
              onPressed: () => ref.read(authRepositoryProvider).signOut(),
              icon: const Icon(Icons.logout),
              label: const Text('Abmelden'),
            ),
            const Divider(height: 48),
            _DatabaseConnectionSection(config: ref.read(appConfigProvider)),
          ],
        ),
      ),
    );
  }
}

/// Zeigt die aktuelle Supabase-Verbindung und – wenn sie zur Laufzeit gesetzt
/// wurde (Onboarding) – einen Knopf zum Zurücksetzen.
class _DatabaseConnectionSection extends StatelessWidget {
  const _DatabaseConnectionSection({required this.config});

  final AppConfig config;

  Future<void> _reset(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Verbindung zurücksetzen?'),
        content: const Text(
          'Die gespeicherte Supabase-Verbindung wird gelöscht. Danach musst '
          'du die App neu starten (oder den Browser-Tab neu laden) und die '
          'Zugangsdaten erneut eingeben. Deine Daten in Supabase bleiben '
          'erhalten.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Abbrechen'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Zurücksetzen'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await config.clear();
    if (!context.mounted) return;
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Zurückgesetzt'),
        content: const Text(
          'Bitte schließe die App und öffne sie neu (am Handy/Desktop) bzw. '
          'lade den Browser-Tab neu, um die Einrichtung erneut zu starten.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Datenbank-Verbindung',
            style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 8),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.cloud_done_outlined),
          title: const Text('Supabase'),
          subtitle: Text(config.url.isEmpty ? '—' : config.url),
        ),
        if (config.isLockedByEnv)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 4),
            child: Text(
              'Diese Verbindung ist über env.json fest eingestellt und kann '
              'hier nicht geändert werden.',
              style: TextStyle(fontStyle: FontStyle.italic),
            ),
          )
        else
          OutlinedButton.icon(
            onPressed: () => _reset(context),
            icon: const Icon(Icons.link_off),
            label: const Text('Verbindung zurücksetzen'),
          ),
      ],
    );
  }
}
