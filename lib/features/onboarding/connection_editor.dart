import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../config/app_config.dart';
import '../../config/remote_connection.dart';
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
            const SizedBox(height: 4),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () => _takeOverFromWeb(context, urlCtrl, keyCtrl),
                icon: const Icon(Icons.bolt_outlined, size: 18),
                label: Text(l.takeOverFromWeb),
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
  // Verbindet neu, ohne dass der Nutzer die App von Hand beenden muss (auf
  // Android beendet "App schliessen"/wechseln den Prozess meist nicht
  // wirklich, wodurch ein reines "bitte neu starten" wirkungslos bliebe).
  await ref.read(appRestartProvider)();
}

/// Fragt einen Link zur Web-Version ab und übernimmt deren Zugangsdaten in
/// die URL-/Key-Felder des Editors (der Nutzer muss danach noch „Speichern"
/// drücken, wie bei manueller Eingabe).
Future<void> _takeOverFromWeb(
  BuildContext context,
  TextEditingController urlCtrl,
  TextEditingController keyCtrl,
) async {
  final l = AppLocalizations.of(context);
  final linkCtrl = TextEditingController();
  final link = await showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(l.takeOverFromWeb),
      content: TextField(
        controller: linkCtrl,
        keyboardType: TextInputType.url,
        autofocus: true,
        decoration: InputDecoration(
          labelText: l.webVersionLink,
          hintText: 'https://dein-name.github.io/dein-repo/',
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: Text(l.cancel)),
        FilledButton(
          onPressed: () => Navigator.pop(ctx, linkCtrl.text.trim()),
          child: Text(l.ok),
        ),
      ],
    ),
  );
  if (link == null || link.isEmpty) return;
  if (!context.mounted) return;

  try {
    final conn = await RemoteConnection.fetch(link);
    urlCtrl.text = conn.url;
    keyCtrl.text = conn.anonKey;
  } on RemoteConnectionException catch (e) {
    if (!context.mounted) return;
    final msg = switch (e.kind) {
      RemoteConnectionError.emptyLink => l.enterLink,
      RemoteConnectionError.invalidLink => l.invalidLink,
      RemoteConnectionError.unreachable => l.remoteConnectionUnreachable(
        e.detail ?? '',
      ),
      RemoteConnectionError.httpError => l.remoteConnectionHttpError(
        e.detail ?? '',
      ),
      RemoteConnectionError.notConnected => l.remoteConnectionNotConnected,
    };
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  } catch (e) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
  }
}
