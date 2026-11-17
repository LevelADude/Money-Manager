import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme.dart';
import '../../l10n/app_localizations.dart';
import '../../shared/money.dart';
import '../currency/currency_picker.dart';
import '../currency/currency_providers.dart';
import '../onboarding/connection_editor.dart';
import 'settings_providers.dart';
import '../../shared/responsive.dart';
import '../../shared/bento.dart';

/// Einstellungen: Sprache, Erscheinungsbild (Farbpalette), Privatsphäre, Währung.
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
        padding: EdgeInsets.all(16).withBarInset(context),
        children: bentoSections([
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
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              for (final (p, label) in [
                (AppPalette.system, l.themeSystem),
                (AppPalette.sage, l.paletteSage),
                (AppPalette.emerald, l.paletteEmerald),
                (AppPalette.dark, l.themeDark),
              ])
                _PaletteSwatch(
                  palette: p,
                  label: label,
                  selected: settings.palette == p,
                  onTap: () => notifier.setPalette(p),
                ),
            ],
          ),
          const Divider(height: 40),
          header(l.privacy),
          SwitchListTile(
            value: settings.hideAmounts,
            onChanged: notifier.setHideAmounts,
            secondary: const Icon(Icons.visibility_off_outlined),
            title: Text(l.hideAmounts),
            subtitle: Text(l.hideAmountsSub),
          ),
          SwitchListTile(
            value: settings.showAvailable,
            onChanged: notifier.setShowAvailable,
            secondary: const Icon(Icons.bookmarks_outlined),
            title: Text(l.settingShowAvailable),
            subtitle: Text(l.settingShowAvailableSub),
          ),
          const Divider(height: 40),
          header(l.currency),
          const SizedBox(height: 8),
          ListTile(
            leading: const Icon(Icons.payments_outlined),
            title: Text(l.mainCurrency),
            subtitle: Text(l.mainCurrencyHelp),
            trailing: Text(
              '${settings.baseCurrency} (${currencySymbol(settings.baseCurrency)})',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            onTap: () async {
              final extras = ref
                  .read(myCurrenciesProvider)
                  .map((c) => c.code)
                  .toList();
              final code = await showCurrencyPicker(
                context,
                selected: settings.baseCurrency,
                extraCodes: extras,
              );
              if (code != null) await notifier.setBaseCurrency(code);
            },
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
          const SizedBox(height: 8),
          Text(
            l.displayCurrencies,
            style: Theme.of(context).textTheme.labelLarge,
          ),
          const SizedBox(height: 2),
          Text(
            l.displayCurrenciesHelp,
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              for (final code in settings.displayCurrencies)
                InputChip(
                  label: Text('$code (${currencySymbol(code)})'),
                  onDeleted: () => notifier.setDisplayCurrencies([
                    for (final c in settings.displayCurrencies)
                      if (c != code) c,
                  ]),
                ),
              ActionChip(
                avatar: const Icon(Icons.add, size: 16),
                label: Text(l.addDisplayCurrency),
                onPressed: () async {
                  final extras = ref
                      .read(myCurrenciesProvider)
                      .map((c) => c.code)
                      .toList();
                  final code = await showCurrencyPicker(
                    context,
                    extraCodes: extras,
                  );
                  if (code != null &&
                      code != settings.baseCurrency &&
                      !settings.displayCurrencies.contains(code)) {
                    await notifier.setDisplayCurrencies([
                      ...settings.displayCurrencies,
                      code,
                    ]);
                  }
                },
              ),
            ],
          ),
          const Divider(height: 40),
          SwitchListTile(
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
            leading: const Icon(Icons.dns_outlined),
            title: Text(l.dbConnection),
            subtitle: Text(l.dbConnectionSub),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => showConnectionEditor(context, ref),
          ),
        ]),
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

/// Auswahlkachel einer Palette: Mini-Vorschau (Hintergrund, Kachel, Akzent)
/// über dem Namen. „System" zeigt links Salbei und rechts Dunkel.
class _PaletteSwatch extends StatelessWidget {
  const _PaletteSwatch({
    required this.palette,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final AppPalette palette;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  Widget _half(ThemeData t) {
    final c = t.extension<AppColors>()!;
    return ColoredBox(
      color: c.background,
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: c.card,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: c.hairline),
          ),
          child: Align(
            alignment: const Alignment(-.6, 0),
            child: Container(
              width: 14,
              height: 14,
              decoration: BoxDecoration(
                color: t.colorScheme.primary,
                shape: BoxShape.circle,
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: SizedBox(
          width: 112,
          child: Column(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                height: 72,
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: selected ? scheme.primary : scheme.outlineVariant,
                    width: selected ? 2.5 : 1,
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(child: _half(AppTheme.themeFor(palette))),
                    if (palette == AppPalette.system)
                      Expanded(child: _half(AppTheme.systemDark)),
                  ],
                ),
              ),
              const SizedBox(height: 6),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (selected) ...[
                    Icon(Icons.check_circle, size: 16, color: scheme.primary),
                    const SizedBox(width: 4),
                  ],
                  Flexible(
                    child: Text(
                      label,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: selected
                            ? FontWeight.w600
                            : FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
