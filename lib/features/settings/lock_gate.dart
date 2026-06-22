import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/app_localizations.dart';
import 'settings_providers.dart';

/// Legt eine PIN-Sperre über die App, wenn aktiviert. Sperrt beim Kaltstart
/// und erneut, sobald die App in den Hintergrund ging.
class LockGate extends ConsumerStatefulWidget {
  const LockGate({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<LockGate> createState() => _LockGateState();
}

class _LockGateState extends ConsumerState<LockGate>
    with WidgetsBindingObserver {
  bool _locked = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _locked = ref.read(settingsProvider).lockEnabled;
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      if (ref.read(settingsProvider).lockEnabled) {
        setState(() => _locked = true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final enabled = ref.watch(settingsProvider.select((s) => s.lockEnabled));
    if (!enabled || !_locked) return widget.child;
    return _PinScreen(
      onSubmit: (pin) {
        final ok = ref.read(settingsProvider.notifier).verifyPin(pin);
        if (ok) setState(() => _locked = false);
        return ok;
      },
    );
  }
}

class _PinScreen extends StatefulWidget {
  const _PinScreen({required this.onSubmit});

  /// Gibt true zurück, wenn die PIN korrekt war.
  final bool Function(String pin) onSubmit;

  @override
  State<_PinScreen> createState() => _PinScreenState();
}

class _PinScreenState extends State<_PinScreen> {
  String _pin = '';
  bool _error = false;
  static const _maxLen = 6;

  void _tap(String d) {
    if (_pin.length >= _maxLen) return;
    setState(() {
      _pin += d;
      _error = false;
    });
  }

  void _back() {
    if (_pin.isEmpty) return;
    setState(() => _pin = _pin.substring(0, _pin.length - 1));
  }

  void _submit() {
    if (_pin.length < 4) return;
    final ok = widget.onSubmit(_pin);
    if (!ok) {
      setState(() {
        _error = true;
        _pin = '';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l = AppLocalizations.of(context);
    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 320),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.lock_outline,
                    size: 48, color: theme.colorScheme.primary),
                const SizedBox(height: 16),
                Text(l.enterPin, style: theme.textTheme.titleMedium),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    for (var i = 0; i < _maxLen; i++)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 5),
                        child: Container(
                          width: 14,
                          height: 14,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: i < _pin.length
                                ? (_error
                                    ? theme.colorScheme.error
                                    : theme.colorScheme.primary)
                                : Colors.transparent,
                            border: Border.all(
                              color: _error
                                  ? theme.colorScheme.error
                                  : theme.colorScheme.outline,
                              width: 2,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                if (_error)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Text(l.wrongPin,
                        style: TextStyle(color: theme.colorScheme.error)),
                  ),
                const SizedBox(height: 20),
                for (final row in const [
                  ['1', '2', '3'],
                  ['4', '5', '6'],
                  ['7', '8', '9'],
                ])
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [for (final d in row) _key(d)],
                  ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _iconKey(Icons.backspace_outlined, _back),
                    _key('0'),
                    _iconKey(Icons.check, _submit),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _key(String d) => Padding(
        padding: const EdgeInsets.all(6),
        child: SizedBox(
          width: 64,
          height: 56,
          child: OutlinedButton(
            onPressed: () => _tap(d),
            child: Text(d, style: const TextStyle(fontSize: 20)),
          ),
        ),
      );

  Widget _iconKey(IconData icon, VoidCallback onTap) => Padding(
        padding: const EdgeInsets.all(6),
        child: SizedBox(
          width: 64,
          height: 56,
          child: FilledButton.tonal(onPressed: onTap, child: Icon(icon)),
        ),
      );
}
