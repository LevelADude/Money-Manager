import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../config/app_config.dart';
import '../../l10n/app_localizations.dart';
import '../auth/auth_providers.dart';
import '../onboarding/connection_editor.dart';
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
        final l = AppLocalizations.of(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l.profileSaved)),
        );
      }
    } catch (e) {
      if (mounted) {
        final l = AppLocalizations.of(context);
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(l.errorWith(e))));
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

    final l = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l.moreProfile)),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ListTile(
              leading: const Icon(Icons.email_outlined),
              title: Text(l.email),
              subtitle: Text(email.isEmpty ? '—' : email),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _name,
              decoration: InputDecoration(
                labelText: l.displayName,
                prefixIcon: const Icon(Icons.person_outline),
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
              label: Text(l.save),
            ),
            const SizedBox(height: 24),
            OutlinedButton.icon(
              onPressed: () => ref.read(authRepositoryProvider).signOut(),
              icon: const Icon(Icons.logout),
              label: Text(l.signOut),
            ),
            const Divider(height: 48),
            const _DatabaseConnectionSection(),
          ],
        ),
      ),
    );
  }
}

/// Zeigt die aktuelle Supabase-Verbindung und erlaubt, sie zu ändern bzw. auf
/// die fest eingebaute Standard-Verbindung zurückzusetzen.
class _DatabaseConnectionSection extends ConsumerWidget {
  const _DatabaseConnectionSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final config = ref.watch(appConfigProvider);
    final l = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(l.dbConnection,
            style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 8),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.cloud_done_outlined),
          title: const Text('Supabase'),
          subtitle: Text(config.url.isEmpty ? '—' : config.url),
        ),
        if (config.isUsingOverride)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text(
              l.customConnectionActive,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        OutlinedButton.icon(
          onPressed: () => showConnectionEditor(context, ref),
          icon: const Icon(Icons.dns_outlined),
          label: Text(l.changeConnection),
        ),
      ],
    );
  }
}
