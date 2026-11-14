import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';

/// Schalter, der sofort umspringt und erst danach speichert.
///
/// [value] ist der Server-Stand (aus dem Live-Stream). Beim Umschalten wird
/// der neue Wert direkt angezeigt; lehnt der Server ab, springt der Schalter
/// zurück und es erscheint eine Fehlermeldung.
class OptimisticSwitch extends StatefulWidget {
  const OptimisticSwitch({
    super.key,
    required this.value,
    required this.onSave,
  });

  final bool value;
  final Future<void> Function(bool value) onSave;

  @override
  State<OptimisticSwitch> createState() => _OptimisticSwitchState();
}

class _OptimisticSwitchState extends State<OptimisticSwitch> {
  /// Lokal vorweggenommener Wert, solange der Server ihn noch nicht bestätigt.
  bool? _pending;

  @override
  void didUpdateWidget(OptimisticSwitch old) {
    super.didUpdateWidget(old);
    // Server hat aufgeholt -> wieder dem Server-Stand folgen.
    if (_pending == widget.value) _pending = null;
  }

  Future<void> _toggle(bool v) async {
    setState(() => _pending = v);
    final messenger = ScaffoldMessenger.of(context);
    final l = AppLocalizations.of(context);
    try {
      await widget.onSave(v);
    } catch (e) {
      if (!mounted) return;
      setState(() => _pending = null);
      messenger.showSnackBar(SnackBar(content: Text(l.errorWith(e))));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Switch(value: _pending ?? widget.value, onChanged: _toggle);
  }
}
