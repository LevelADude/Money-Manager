import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'person_filter.dart';

/// AppBar-Aktion zum Filtern nach Person (Konto-Besitzer). Erscheint nur, wenn
/// es mehr als einen Besitzer gibt.
class PersonFilterButton extends ConsumerWidget {
  const PersonFilterButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final options = ref.watch(ownerOptionsProvider);
    if (options.length < 2) return const SizedBox.shrink();
    final selected = ref.watch(personFilterProvider);
    final active = selected != null;
    return PopupMenuButton<String?>(
      tooltip: 'Nach Person filtern',
      icon: Icon(active ? Icons.person : Icons.person_outline,
          color: active ? Theme.of(context).colorScheme.primary : null),
      onSelected: (v) => ref.read(personFilterProvider.notifier).set(v),
      itemBuilder: (ctx) => [
        CheckedPopupMenuItem<String?>(
          value: null,
          checked: selected == null,
          child: const Text('Alle Personen'),
        ),
        for (final o in options)
          CheckedPopupMenuItem<String?>(
            value: o.id,
            checked: selected == o.id,
            child: Text(o.name),
          ),
      ],
    );
  }
}
