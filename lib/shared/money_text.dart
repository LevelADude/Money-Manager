import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/settings/settings_providers.dart';
import 'money.dart';

/// Zeigt einen Geldbetrag an und respektiert die Einstellung „Beträge
/// verbergen" (dann „••••"). Reagiert sofort auf das Umschalten.
class MoneyText extends ConsumerWidget {
  const MoneyText(
    this.cents, {
    super.key,
    this.style,
    this.prefix = '',
    this.textAlign,
  });

  final int cents;
  final TextStyle? style;
  final String prefix;
  final TextAlign? textAlign;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hide = ref.watch(settingsProvider.select((s) => s.hideAmounts));
    final text = hide ? '••••' : '$prefix${formatCents(cents)}';
    return Text(text, style: style, textAlign: textAlign);
  }
}
