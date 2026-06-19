import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/access_grant.dart';
import '../auth/auth_providers.dart';
import '../profile/profile_providers.dart';
import 'access_grant_providers.dart';

/// „Freigaben": legt fest, wer die eigenen Finanzen ansehen/verwalten darf,
/// und zeigt, wer dem aktuellen Nutzer Zugriff gegeben hat.
class SharingScreen extends ConsumerWidget {
  const SharingScreen({super.key});

  Future<void> _set(WidgetRef ref, String granteeId, String choice) async {
    final repo = ref.read(accessGrantRepositoryProvider);
    if (choice == 'none') {
      await repo.revoke(granteeId);
    } else {
      await repo.grant(
          granteeId, choice == 'manage' ? GrantLevel.manage : GrantLevel.view);
    }
    ref.invalidate(accessGrantsProvider);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final myId = ref.watch(currentUserIdProvider);
    final names =
        ref.watch(profileNamesProvider).asData?.value ?? const <String, String>{};
    final iGave = ref.watch(grantsIGaveProvider);
    final iReceived = ref.watch(grantsIReceivedProvider);

    String nameOf(String id) =>
        names[id]?.isNotEmpty == true ? names[id]! : 'Unbekannt';

    final others = names.keys.where((id) => id != myId).toList()
      ..sort((a, b) => nameOf(a).toLowerCase().compareTo(nameOf(b).toLowerCase()));

    return Scaffold(
      appBar: AppBar(title: const Text('Freigaben')),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Text(
                'Standardmäßig sieht jede Person nur die eigenen Finanzen. '
                'Hier gibst du anderen Zugriff:\n'
                '• Ansehen: kann deine Konten/Buchungen sehen.\n'
                '• Verwalten: darf zusätzlich Buchungen anlegen und ändern.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 8, 4, 4),
            child: Text('Wer darf auf meine Finanzen zugreifen?',
                style: Theme.of(context)
                    .textTheme
                    .titleSmall
                    ?.copyWith(fontWeight: FontWeight.bold)),
          ),
          if (others.isEmpty)
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text('Es sind keine weiteren Personen registriert.'),
            )
          else
            for (final id in others)
              Card(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          CircleAvatar(
                            radius: 16,
                            child: Text(nameOf(id).isNotEmpty
                                ? nameOf(id)[0].toUpperCase()
                                : '?'),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(nameOf(id),
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      SegmentedButton<String>(
                        showSelectedIcon: false,
                        segments: const [
                          ButtonSegment(value: 'none', label: Text('Kein')),
                          ButtonSegment(value: 'view', label: Text('Ansehen')),
                          ButtonSegment(
                              value: 'manage', label: Text('Verwalten')),
                        ],
                        selected: {
                          switch (iGave[id]) {
                            GrantLevel.manage => 'manage',
                            GrantLevel.view => 'view',
                            null => 'none',
                          }
                        },
                        onSelectionChanged: (s) => _set(ref, id, s.first),
                      ),
                    ],
                  ),
                ),
              ),
          const Divider(height: 32),
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 0, 4, 4),
            child: Text('Wer hat mir Zugriff gegeben?',
                style: Theme.of(context)
                    .textTheme
                    .titleSmall
                    ?.copyWith(fontWeight: FontWeight.bold)),
          ),
          if (iReceived.isEmpty)
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text('Noch niemand hat dir Zugriff gegeben.'),
            )
          else
            for (final e in iReceived.entries)
              ListTile(
                leading: const Icon(Icons.visibility_outlined),
                title: Text(nameOf(e.key)),
                subtitle: Text(e.value == GrantLevel.manage
                    ? 'Du darfst ansehen und verwalten'
                    : 'Du darfst ansehen'),
              ),
        ],
      ),
    );
  }
}
