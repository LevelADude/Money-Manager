import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../config/app_config.dart';
import '../../l10n/app_localizations.dart';

/// Dialog zum Ändern der Datenbank-Verbindung (URL + Key) pro Gerät – inkl.
/// Zurücksetzen auf die fest eingebaute Standard-Verbindung.
///
/// Erreichbar vom Login (falls man eine falsche URL eingegeben hat und sonst
/// nicht mehr herankäme) und aus dem Profil.
Future<void> showConnectionEditor(BuildContext context, WidgetRef ref) async {
  final l = AppLocalizations.of(context);
  final config = ref.read(appConfigProvider);
  final urlCtrl = TextEditingController(text: config.url);
  final keyCtrl = TextEditingController(text: config.anonKey);

  final action = await showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(l.dbConnection),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(l.connectionEditorIntro),
            const SizedBox(height: 12),
            TextField(
              controller: urlCtrl,
              keyboardType: TextInputType.url,
              decoration: InputDecoration(
                labelText: l.supabaseUrlLabel,
                hintText: 'https://xxxx.supabase.co',
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: keyCtrl,
              minLines: 1,
              maxLines: 3,
              decoration: InputDecoration(labelText: l.anonKeyLabel),
            ),
          ],
        ),
      ),
      actions: [
        // Override aktiv -> auf Standard zurücksetzen. Keine feste Verbindung
        // eingebaut (Fork) -> Verbindung trennen und zurück zur Einrichtung.
        if (config.isUsingOverride || !config.hasBakedDefault)
          TextButton(
            onPressed: () => Navigator.pop(ctx, 'reset'),
            child: Text(
              config.hasBakedDefault ? l.resetToDefault : l.disconnect,
            ),
          ),
        TextButton(onPressed: () => Navigator.pop(ctx), child: Text(l.cancel)),
        FilledButton(
          onPressed: () {
            if (urlCtrl.text.trim().isEmpty || keyCtrl.text.trim().isEmpty) {
              return;
            }
            Navigator.pop(ctx, 'save');
          },
          child: Text(l.save),
        ),
      ],
    ),
  );

  if (action == 'save') {
    await config.save(url: urlCtrl.text, anonKey: keyCtrl.text);
  } else if (action == 'reset') {
    await config.clear();
  } else {
    return;
  }
  if (!context.mounted) return;
  await showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(l.connectionChanged),
      content: Text(l.connectionChangedBody),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: Text(l.ok)),
      ],
    ),
  );
}
