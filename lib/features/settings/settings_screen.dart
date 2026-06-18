import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'settings_providers.dart';

/// Einstellungen: Erscheinungsbild (Theme-Modus + Akzentfarbe).
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final notifier = ref.read(settingsProvider.notifier);

    return Scaffold(
      appBar: AppBar(title: const Text('Einstellungen')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('Erscheinungsbild',
              style: Theme.of(context)
                  .textTheme
                  .titleSmall
                  ?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          SegmentedButton<ThemeMode>(
            segments: const [
              ButtonSegment(
                  value: ThemeMode.system,
                  label: Text('System'),
                  icon: Icon(Icons.brightness_auto)),
              ButtonSegment(
                  value: ThemeMode.light,
                  label: Text('Hell'),
                  icon: Icon(Icons.light_mode)),
              ButtonSegment(
                  value: ThemeMode.dark,
                  label: Text('Dunkel'),
                  icon: Icon(Icons.dark_mode)),
            ],
            selected: {settings.themeMode},
            onSelectionChanged: (s) => notifier.setThemeMode(s.first),
          ),
          const SizedBox(height: 24),
          Text('Akzentfarbe',
              style: Theme.of(context)
                  .textTheme
                  .titleSmall
                  ?.copyWith(fontWeight: FontWeight.bold)),
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
          Text('Privatsphäre',
              style: Theme.of(context)
                  .textTheme
                  .titleSmall
                  ?.copyWith(fontWeight: FontWeight.bold)),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: settings.hideAmounts,
            onChanged: notifier.setHideAmounts,
            secondary: const Icon(Icons.visibility_off_outlined),
            title: const Text('Beträge verbergen'),
            subtitle: const Text('Zeigt „••••" statt Geldbeträgen'),
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
            title: const Text('App-Sperre (PIN)'),
            subtitle: const Text('PIN-Abfrage beim Start und nach Pause'),
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
                  label: const Text('PIN ändern'),
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// Dialog zum Festlegen einer neuen PIN (4–6 Ziffern, zweimal eingeben).
  Future<String?> _askNewPin(BuildContext context) async {
    final pin1 = TextEditingController();
    final pin2 = TextEditingController();
    final formKey = GlobalKey<FormState>();
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('PIN festlegen'),
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
                decoration: const InputDecoration(labelText: 'PIN (4–6 Ziffern)'),
                validator: (v) {
                  final t = (v ?? '').trim();
                  if (t.length < 4) return 'Mindestens 4 Ziffern';
                  if (int.tryParse(t) == null) return 'Nur Ziffern';
                  return null;
                },
              ),
              TextFormField(
                controller: pin2,
                keyboardType: TextInputType.number,
                obscureText: true,
                maxLength: 6,
                decoration: const InputDecoration(labelText: 'PIN wiederholen'),
                validator: (v) =>
                    (v ?? '').trim() != pin1.text.trim() ? 'Stimmt nicht überein' : null,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Abbrechen'),
          ),
          FilledButton(
            onPressed: () {
              if (formKey.currentState!.validate()) {
                Navigator.pop(ctx, pin1.text.trim());
              }
            },
            child: const Text('Speichern'),
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
        child: selected
            ? const Icon(Icons.check, color: Colors.white)
            : null,
      ),
    );
  }
}
