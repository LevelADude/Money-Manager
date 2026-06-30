import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../l10n/app_localizations.dart';
import '../../shared/money.dart';
import '../currency/add_currency.dart';
import '../currency/currency_providers.dart';
import '../onboarding/connection_editor.dart';
import 'settings_providers.dart';

/// Einstellungen: Erscheinungsbild (Theme-Modus + Akzentfarbe).
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final notifier = ref.read(settingsProvider.notifier);
    final l = AppLocalizations.of(context);

    Widget header(String text) => Text(
      text,
      style: Theme.of(
        context,
      ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
    );

    return Scaffold(
      appBar: AppBar(title: Text(l.settingsTitle)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          header(l.language),
          const SizedBox(height: 8),
          SegmentedButton<String>(
            segments: [
              ButtonSegment(
                value: 'de',
                label: Text(l.languageGerman),
                icon: const Icon(Icons.translate),
              ),
              ButtonSegment(value: 'en', label: Text(l.languageEnglish)),
            ],
            selected: {settings.localeCode},
            onSelectionChanged: (s) => notifier.setLocale(s.first),
          ),
          const Divider(height: 40),
          header(l.appearance),
          const SizedBox(height: 8),
          SegmentedButton<ThemeMode>(
            segments: [
              ButtonSegment(
                value: ThemeMode.system,
                label: Text(l.themeSystem),
                icon: const Icon(Icons.brightness_auto),
              ),
              ButtonSegment(
                value: ThemeMode.light,
                label: Text(l.themeLight),
                icon: const Icon(Icons.light_mode),
              ),
              ButtonSegment(
                value: ThemeMode.dark,
                label: Text(l.themeDark),
                icon: const Icon(Icons.dark_mode),
              ),
            ],
            selected: {settings.themeMode},
            onSelectionChanged: (s) => notifier.setThemeMode(s.first),
          ),
          const SizedBox(height: 24),
          header(l.accentColor),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              for (final c in accentColors)
                _ColorSwatch(
                  color: Color(c),
                  selected: settings.seedColor == c,
                  onTap: () => notifier.setSeedColor(c),
                ),
            ],
          ),
          const Divider(height: 40),
          header(l.privacy),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: settings.hideAmounts,
            onChanged: notifier.setHideAmounts,
            secondary: const Icon(Icons.visibility_off_outlined),
            title: Text(l.hideAmounts),
            subtitle: Text(l.hideAmountsSub),
          ),
          const Divider(height: 40),
          header(l.currency),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  initialValue:
                      ref
                          .watch(allCurrenciesProvider)
                          .contains(settings.baseCurrency)
                      ? settings.baseCurrency
                      : 'EUR',
                  decoration: InputDecoration(
                    labelText: l.mainCurrency,
                    prefixIcon: const Icon(Icons.payments_outlined),
                    helperText: l.mainCurrencyHelp,
                  ),
                  items: [
                    for (final c in ref.watch(allCurrenciesProvider))
                      DropdownMenuItem(
                        value: c,
                        child: Text('$c (${currencySymbol(c)})'),
                      ),
                  ],
                  onChanged: (v) {
                    if (v != null) notifier.setBaseCurrency(v);
                  },
                ),
              ),
              IconButton(
                tooltip: l.addCurrency,
                icon: const Icon(Icons.add),
                onPressed: () async {
                  final code = await showAddCurrencyDialog(context);
                  if (code != null) {
                    await ref.read(customCurrenciesProvider.notifier).add(code);
                  }
                },
              ),
            ],
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () => context.go('/more/exchange-rates'),
              icon: const Icon(Icons.currency_exchange),
              label: Text(l.manageRates),
            ),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: settings.lockEnabled,
            onChanged: (v) async {
              if (v) {
                final pin = await _askNewPin(context);
                if (pin != null) await notifier.setPin(pin);
              } else {
                await notifier.disableLock();
              }
            },
            secondary: const Icon(Icons.lock_outline),
            title: Text(l.appLock),
            subtitle: Text(l.appLockSub),
          ),
          if (settings.lockEnabled)
            Padding(
              padding: const EdgeInsets.only(left: 16),
              child: Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: () async {
                    final pin = await _askNewPin(context);
                    if (pin != null) await notifier.setPin(pin);
                  },
                  icon: const Icon(Icons.password),
                  label: Text(l.changePin),
                ),
              ),
            ),
          const Divider(height: 40),
          header(l.database),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.dns_outlined),
            title: Text(l.dbConnection),
            subtitle: Text(l.dbConnectionSub),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => showConnectionEditor(context, ref),
          ),
        ],
      ),
    );
  }

  /// Dialog zum Festlegen einer neuen PIN (4–6 Ziffern, zweimal eingeben).
  Future<String?> _askNewPin(BuildContext context) async {
    final l = AppLocalizations.of(context);
    final pin1 = TextEditingController();
    final pin2 = TextEditingController();
    final formKey = GlobalKey<FormState>();
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l.setPinTitle),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: pin1,
                keyboardType: TextInputType.number,
                obscureText: true,
                maxLength: 6,
                decoration: InputDecoration(labelText: l.pinLabel),
                validator: (v) {
                  final t = (v ?? '').trim();
                  if (t.length < 4) return l.pinMin;
                  if (int.tryParse(t) == null) return l.pinDigitsOnly;
                  return null;
                },
              ),
              TextFormField(
                controller: pin2,
                keyboardType: TextInputType.number,
                obscureText: true,
                maxLength: 6,
                decoration: InputDecoration(labelText: l.pinRepeat),
                validator: (v) =>
                    (v ?? '').trim() != pin1.text.trim() ? l.pinMismatch : null,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l.cancel),
          ),
          FilledButton(
            onPressed: () {
              if (formKey.currentState!.validate()) {
                Navigator.pop(ctx, pin1.text.trim());
              }
            },
            child: Text(l.save),
          ),
        ],
      ),
    );
    return result;
  }
}

class _ColorSwatch extends StatelessWidget {
  const _ColorSwatch({
    required this.color,
    required this.selected,
    required this.onTap,
  });

  final Color color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(28),
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(
            color: selected
                ? Theme.of(context).colorScheme.onSurface
                : Colors.transparent,
            width: 3,
          ),
        ),
        child: selected ? const Icon(Icons.check, color: Colors.white) : null,
      ),
    );
  }
}
