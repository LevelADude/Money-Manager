import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/settings/settings_providers.dart';
import '../l10n/app_localizations.dart';

/// AppBar-Aktion zum schnellen Ein-/Ausblenden aller Geldbeträge
/// (Privatsphäre) — spiegelt/steuert dieselbe Einstellung wie
/// Einstellungen → Privatsphäre.
class HideAmountsToggle extends ConsumerWidget {
  const HideAmountsToggle({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final hide = ref.watch(settingsProvider.select((s) => s.hideAmounts));
    return IconButton(
      tooltip: hide ? l.showAmounts : l.hideAmounts,
      icon: Icon(
        hide ? Icons.visibility_off_outlined : Icons.visibility_outlined,
      ),
      onPressed: () =>
          ref.read(settingsProvider.notifier).setHideAmounts(!hide),
    );
  }
}
