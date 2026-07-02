import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/app_localizations.dart';
import '../auth/auth_providers.dart';
import '../transactions/person_filter.dart';
import 'profile_providers.dart';

/// Profil-Icon oben in der AppBar zum Wechseln der angezeigten Person.
///
/// Standard ist „Ich" (nur eigene Finanzen). Über das Menü kann auf „Alle
/// Personen" oder eine andere Person umgeschaltet werden. Spätere Phasen
/// beschränken die wählbaren Personen auf solche, die Zugriff erteilt haben.
class ProfileSwitcher extends ConsumerWidget {
  const ProfileSwitcher({super.key});

  static const _signOutValue = '__sign_out__';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final myId = ref.watch(currentUserIdProvider);
    final options = ref.watch(ownerOptionsProvider);
    final names =
        ref.watch(profileNamesProvider).asData?.value ??
        const <String, String>{};
    final selected = ref.watch(personFilterProvider);
    final l = AppLocalizations.of(context);

    String nameOf(String id) =>
        names[id]?.isNotEmpty == true ? names[id]! : l.personFallback;
    final myName = myId == null
        ? l.meWord
        : (names[myId]?.isNotEmpty == true ? names[myId]! : l.meWord);

    // Avatar-Inhalt: Gruppen-Icon bei „Alle", sonst Initiale der Person.
    Widget avatar() {
      if (selected == null) {
        return const Icon(Icons.groups_outlined, size: 18);
      }
      final label = selected == myId ? myName : nameOf(selected);
      final initial = label.isNotEmpty ? label[0].toUpperCase() : '?';
      return Text(
        initial,
        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
      );
    }

    // Andere Personen, auf die ich Zugriff habe (eigene Konten ausgenommen).
    final otherOwners = [
      for (final o in options)
        if (o.id != myId) o,
    ];
    final hasOthers = otherOwners.isNotEmpty;

    return PopupMenuButton<String?>(
      tooltip: l.switchPerson,
      offset: const Offset(0, 48),
      icon: CircleAvatar(
        radius: 15,
        backgroundColor: selected == null
            ? Theme.of(context).colorScheme.surfaceContainerHighest
            : Theme.of(context).colorScheme.primaryContainer,
        foregroundColor: Theme.of(context).colorScheme.onPrimaryContainer,
        child: avatar(),
      ),
      onSelected: (v) {
        if (v == _signOutValue) {
          ref.read(authRepositoryProvider).signOut();
          return;
        }
        ref.read(personFilterProvider.notifier).set(v);
      },
      itemBuilder: (ctx) => [
        if (myId != null)
          CheckedPopupMenuItem<String?>(
            value: myId,
            checked: selected == myId,
            child: Text(l.nameWithMe(myName)),
          ),
        // „Alle Personen" nur anzeigen, wenn es überhaupt andere gibt – sonst
        // wäre es identisch zur Eigenansicht (und schien „ohne Funktion").
        if (hasOthers)
          CheckedPopupMenuItem<String?>(
            value: null,
            checked: selected == null,
            child: Text(l.allPersons),
          ),
        for (final o in otherOwners)
          CheckedPopupMenuItem<String?>(
            value: o.id,
            checked: selected == o.id,
            child: Text(o.name),
          ),
        const PopupMenuDivider(),
        PopupMenuItem<String?>(
          value: _signOutValue,
          child: Row(
            children: [
              const Icon(Icons.logout, size: 18),
              const SizedBox(width: 8),
              Text(l.signOut),
            ],
          ),
        ),
      ],
    );
  }
}
