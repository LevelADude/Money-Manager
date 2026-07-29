import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../../shared/money.dart';
import '../../shared/world_currencies.dart';
import 'add_currency.dart';

/// Öffnet eine durchsuchbare Währungsauswahl (alle Weltwährungen + optionale
/// Zusatz-Codes wie eigene/Krypto-Währungen). Gibt den gewählten Code zurück
/// oder `null` bei Abbruch.
Future<String?> showCurrencyPicker(
  BuildContext context, {
  String? selected,
  List<String> extraCodes = const [],
}) {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (ctx) =>
        _CurrencyPickerSheet(selected: selected, extraCodes: extraCodes),
  );
}

class _Entry {
  const _Entry(this.code, this.name, this.symbol);
  final String code;
  final String name;
  final String symbol;
}

class _CurrencyPickerSheet extends StatefulWidget {
  const _CurrencyPickerSheet({this.selected, this.extraCodes = const []});

  final String? selected;
  final List<String> extraCodes;

  @override
  State<_CurrencyPickerSheet> createState() => _CurrencyPickerSheetState();
}

class _CurrencyPickerSheetState extends State<_CurrencyPickerSheet> {
  String _query = '';

  List<_Entry> get _all {
    final seen = <String>{};
    final list = <_Entry>[];
    // Zusatz-Codes (z. B. eigene/Krypto) zuerst.
    for (final code in widget.extraCodes) {
      if (seen.add(code)) {
        final w = worldCurrencyByCode[code];
        list.add(_Entry(code, w?.name ?? code, currencySymbol(code)));
      }
    }
    for (final c in worldCurrencies) {
      if (seen.add(c.code)) list.add(_Entry(c.code, c.name, c.symbol));
    }
    return list;
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final q = _query.trim().toLowerCase();
    final items = q.isEmpty
        ? _all
        : _all
              .where(
                (e) =>
                    e.code.toLowerCase().contains(q) ||
                    e.name.toLowerCase().contains(q),
              )
              .toList();
    final viewInsets = MediaQuery.of(context).viewInsets.bottom;
    final maxH = MediaQuery.of(context).size.height * 0.8;

    return Padding(
      padding: EdgeInsets.only(bottom: viewInsets),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxH),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: TextField(
                autofocus: true,
                decoration: InputDecoration(
                  hintText: l.searchCurrency,
                  prefixIcon: const Icon(Icons.search),
                  isDense: true,
                  border: const OutlineInputBorder(),
                ),
                onChanged: (v) => setState(() => _query = v),
              ),
            ),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: items.length + 1,
                itemBuilder: (ctx, i) {
                  if (i == items.length) {
                    // Letzter Eintrag: eigener Code (Krypto/unlisted).
                    return ListTile(
                      leading: const Icon(Icons.add),
                      title: Text(l.customCode),
                      onTap: () async {
                        final code = await showAddCurrencyDialog(context);
                        if (code != null && ctx.mounted) {
                          Navigator.pop(ctx, code);
                        }
                      },
                    );
                  }
                  final e = items[i];
                  final sel = e.code == widget.selected;
                  return ListTile(
                    dense: true,
                    leading: SizedBox(
                      width: 40,
                      child: Text(
                        e.symbol,
                        style: Theme.of(context).textTheme.titleMedium,
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    title: Text('${e.code} · ${e.name}'),
                    trailing: sel
                        ? Icon(
                            Icons.check,
                            color: Theme.of(context).colorScheme.primary,
                          )
                        : null,
                    onTap: () => Navigator.pop(context, e.code),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
