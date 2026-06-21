import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../config/app_config.dart';

/// Dialog zum Ändern der Datenbank-Verbindung (URL + Key) pro Gerät – inkl.
/// Zurücksetzen auf die fest eingebaute Standard-Verbindung.
///
/// Erreichbar vom Login (falls man eine falsche URL eingegeben hat und sonst
/// nicht mehr herankäme) und aus dem Profil.
Future<void> showConnectionEditor(BuildContext context, WidgetRef ref) async {
  final config = ref.read(appConfigProvider);
  final urlCtrl = TextEditingController(text: config.url);
  final keyCtrl = TextEditingController(text: config.anonKey);

  final action = await showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Datenbank-Verbindung'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Nur ändern, wenn du eine andere Supabase-Datenbank nutzen willst '
              '(z. B. weil die URL falsch war). Die Änderung gilt nur auf diesem '
              'Gerät.',
            ),
            const SizedBox(height: 12),
            TextField(
              controller: urlCtrl,
              keyboardType: TextInputType.url,
              decoration: const InputDecoration(
                labelText: 'Supabase-URL',
                hintText: 'https://xxxx.supabase.co',
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: keyCtrl,
              minLines: 1,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'anon / publishable Key',
              ),
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
            child: Text(config.hasBakedDefault
                ? 'Auf Standard zurücksetzen'
                : 'Verbindung trennen'),
          ),
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Abbrechen'),
        ),
        FilledButton(
          onPressed: () {
            if (urlCtrl.text.trim().isEmpty || keyCtrl.text.trim().isEmpty) {
              return;
            }
            Navigator.pop(ctx, 'save');
          },
          child: const Text('Speichern'),
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
      title: const Text('Verbindung geändert'),
      content: const Text(
        'Bitte lade die Seite neu (Strg+R) bzw. starte die App neu, damit die '
        'neue Verbindung wirksam wird. Deine Daten in Supabase bleiben erhalten.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('OK'),
        ),
      ],
    ),
  );
}
