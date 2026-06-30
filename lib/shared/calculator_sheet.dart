import 'package:flutter/material.dart';

import 'money.dart';

/// Öffnet ein Taschenrechner-Tastenfeld als Bottom-Sheet. Gibt den berechneten
/// Betrag als Eingabe-String ("12,50") zurück – oder null bei Abbruch.
Future<String?> showCalculatorSheet(
  BuildContext context, {
  String initial = '',
}) {
  return showModalBottomSheet<String>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    // Auf breiten Screens zentriert + begrenzt statt über die ganze Breite.
    constraints: const BoxConstraints(maxWidth: 480),
    builder: (_) => _CalculatorSheet(initial: initial),
  );
}

class _CalculatorSheet extends StatefulWidget {
  const _CalculatorSheet({required this.initial});

  final String initial;

  @override
  State<_CalculatorSheet> createState() => _CalculatorSheetState();
}

class _CalculatorSheetState extends State<_CalculatorSheet> {
  late String _expr = widget.initial.replaceAll(RegExp(r'[^0-9.,+\-*/()]'), '');

  String get _display =>
      (_expr.isEmpty ? '0' : _expr).replaceAll('*', '×').replaceAll('/', '÷');

  double? get _result => _expr.isEmpty ? 0 : evalExpression(_expr);

  void _tap(String s) => setState(() => _expr += s);
  void _clear() => setState(() => _expr = '');
  void _back() => setState(() {
    if (_expr.isNotEmpty) _expr = _expr.substring(0, _expr.length - 1);
  });
  void _apply() {
    final v = _result;
    Navigator.pop(context, v?.toStringAsFixed(2).replaceAll('.', ','));
  }

  @override
  Widget build(BuildContext context) {
    final res = _result;
    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 8,
        bottom: MediaQuery.viewInsetsOf(context).bottom + 16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  _display,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 4),
                Text(
                  res == null
                      ? 'ungültig'
                      : '= ${formatCents((res * 100).round())}',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: res == null
                        ? Theme.of(context).colorScheme.error
                        : Theme.of(context).colorScheme.primary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          _row(const ['C', '(', ')', '÷']),
          _row(const ['7', '8', '9', '×']),
          _row(const ['4', '5', '6', '-']),
          _row(const ['1', '2', '3', '+']),
          _row(const [',', '0', '⌫', '=']),
          const SizedBox(height: 8),
          FilledButton.icon(
            onPressed: _apply,
            icon: const Icon(Icons.check),
            label: const Text('Übernehmen'),
          ),
        ],
      ),
    );
  }

  Widget _row(List<String> keys) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      children: [
        for (final k in keys)
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: _key(k),
            ),
          ),
      ],
    ),
  );

  Widget _key(String k) {
    final VoidCallback onTap = switch (k) {
      'C' => _clear,
      '⌫' => _back,
      '=' => _apply,
      '÷' => () => _tap('/'),
      '×' => () => _tap('*'),
      _ => () => _tap(k),
    };
    final isControl = const [
      'C',
      '(',
      ')',
      '÷',
      '×',
      '-',
      '+',
      '=',
      '⌫',
    ].contains(k);
    final child = Text(k, style: const TextStyle(fontSize: 20));
    return SizedBox(
      height: 56,
      child: isControl
          ? FilledButton.tonal(onPressed: onTap, child: child)
          : OutlinedButton(onPressed: onTap, child: child),
    );
  }
}
