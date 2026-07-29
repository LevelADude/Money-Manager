import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/currency/currency_providers.dart';
import '../features/settings/settings_providers.dart';
import 'money.dart';

/// Zeigt einen (in Hauptwährung vorliegenden) Betrag zusätzlich in den vom
/// Nutzer gewählten Anzeigewährungen an (Live-Umrechnung). Nichts, wenn keine
/// Zusatzwährungen gewählt sind, kein Kurs vorliegt oder Beträge verborgen sind.
class MultiCurrencyText extends ConsumerWidget {
  const MultiCurrencyText(
    this.baseCents, {
    super.key,
    this.style,
    this.textAlign,
    this.separator = '   ',
  });

  /// Betrag in Cent, ausgedrückt in der Hauptwährung.
  final int baseCents;
  final TextStyle? style;
  final TextAlign? textAlign;
  final String separator;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hide = ref.watch(settingsProvider.select((s) => s.hideAmounts));
    if (hide) return const SizedBox.shrink();
    final displays = ref.watch(
      settingsProvider.select((s) => s.displayCurrencies),
    );
    if (displays.isEmpty) return const SizedBox.shrink();
    final base = ref.watch(settingsProvider.select((s) => s.baseCurrency));
    final rates = ref.watch(effectiveRatesProvider);

    final parts = <String>[];
    for (final code in displays) {
      if (code == base) continue;
      final rate = rates[code];
      if (rate == null || rate <= 0) continue; // kein Kurs -> überspringen
      final cents = (baseCents / rate).round();
      parts.add('≈ ${formatMoney(cents, code)}');
    }
    if (parts.isEmpty) return const SizedBox.shrink();

    final effectiveStyle =
        style ??
        Theme.of(
          context,
        ).textTheme.bodySmall?.copyWith(color: Theme.of(context).hintColor);
    return Text(
      parts.join(separator),
      style: effectiveStyle,
      textAlign: textAlign,
    );
  }
}
