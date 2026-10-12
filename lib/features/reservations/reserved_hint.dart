import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/app_localizations.dart';
import '../../shared/money.dart';
import '../settings/settings_providers.dart';

/// Der groß angezeigte Betrag laut Einstellung: verfügbar (Saldo minus
/// Reserviert) oder gesamt.
int primaryAmount(int totalCents, int reservedCents, bool showAvailable) =>
    showAvailable ? totalCents - reservedCents : totalCents;

/// Kleine Zeile unter einem Saldo: „Gesamt X · davon Y reserviert" bzw. bei
/// umgestellter Anzeige „Verfügbar X · Y reserviert".
///
/// Erscheint nur, wenn etwas reserviert ist, und verschwindet bei „Beträge
/// verbergen" komplett (statt „****" anzuzeigen).
class ReservedHint extends ConsumerWidget {
  const ReservedHint({
    super.key,
    required this.totalCents,
    required this.reservedCents,
    this.currency,
    this.textAlign,
    this.style,
  });

  final int totalCents;
  final int reservedCents;

  /// Währung der Beträge (null = Hauptwährung).
  final String? currency;
  final TextAlign? textAlign;
  final TextStyle? style;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hide = ref.watch(settingsProvider.select((s) => s.hideAmounts));
    final showAvailable = ref.watch(
      settingsProvider.select((s) => s.showAvailable),
    );
    if (hide || reservedCents == 0) return const SizedBox.shrink();
    final l = AppLocalizations.of(context);
    String fmt(int c) =>
        currency == null ? formatCents(c) : formatMoney(c, currency!);
    final text = showAvailable
        ? l.totalWithReserved(fmt(totalCents), fmt(reservedCents))
        : l.availableWithReserved(
            fmt(totalCents - reservedCents),
            fmt(reservedCents),
          );
    return Text(
      text,
      textAlign: textAlign,
      style:
          style ??
          Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: Theme.of(context).hintColor),
    );
  }
}
