import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../config/app_config.dart';
import '../../shared/responsive.dart';

/// Welcher Einrichtungs-Weg wurde gewählt?
enum _SetupMode {
  /// Neue, eigene Datenbank anlegen (kompletter Guide inkl. setup.sql).
  fresh,

  /// Mit einer bereits eingerichteten Datenbank verbinden (nur URL + Key).
  existing,
}

/// Erststart-Einrichtung: lässt zuerst zwischen „neue eigene Datenbank" und
/// „bestehende Datenbank verbinden" wählen und fragt dann die Supabase-URL +
/// den Schlüssel ab.
///
/// Läuft VOR der Initialisierung von Supabase/Riverpod, bekommt deshalb
/// [config] und [onSubmit] direkt übergeben.
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({
    super.key,
    required this.config,
    required this.onSubmit,
    this.initialError,
  });

  final AppConfig config;

  /// Speichert die Werte und initialisiert Supabase. Gibt eine Fehlermeldung
  /// zurück (oder null bei Erfolg).
  final Future<String?> Function(String url, String anonKey) onSubmit;

  final String? initialError;

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _formKey = GlobalKey<FormState>();
  late final _url = TextEditingController(text: widget.config.url);
  late final _key = TextEditingController(text: widget.config.anonKey);
  bool _busy = false;
  String? _error;
  _SetupMode? _mode;

  @override
  void initState() {
    super.initState();
    _error = widget.initialError;
  }

  @override
  void dispose() {
    _url.dispose();
    _key.dispose();
    super.dispose();
  }

  Future<void> _copySetupSql() async {
    try {
      final sql = await rootBundle.loadString('supabase/setup.sql');
      await Clipboard.setData(ClipboardData(text: sql));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              'SQL kopiert. Im Supabase-Dashboard unter „SQL Editor" einfügen und „Run".'),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Konnte SQL nicht laden: $e')));
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    final error = await widget.onSubmit(_url.text.trim(), _key.text.trim());
    if (!mounted) return;
    setState(() {
      _busy = false;
      _error = error;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Einrichtung'),
        leading: _mode == null
            ? null
            : IconButton(
                icon: const Icon(Icons.arrow_back),
                tooltip: 'Zurück zur Auswahl',
                onPressed: _busy ? null : () => setState(() => _mode = null),
              ),
      ),
      body: MaxWidthBox(
        maxWidth: 640,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: _mode == null ? _buildChooser(theme) : _buildForm(theme),
        ),
      ),
    );
  }

  /// Erststart-Auswahl: neue eigene DB oder bestehende verbinden.
  Widget _buildChooser(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Icon(Icons.cloud_sync_outlined,
            size: 48, color: theme.colorScheme.primary),
        const SizedBox(height: 12),
        Text('Willkommen bei Money Manager',
            textAlign: TextAlign.center, style: theme.textTheme.headlineSmall),
        const SizedBox(height: 8),
        Text(
          'Deine Daten liegen in deinem eigenen, kostenlosen Supabase-Projekt. '
          'Wie möchtest du starten?',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium,
        ),
        const SizedBox(height: 20),
        _ChoiceCard(
          icon: Icons.add_circle_outline,
          title: 'Neue Installation',
          subtitle:
              'Eigene, leere Datenbank anlegen und einrichten. Die erste Person, '
              'die sich registriert, wird Besitzer.',
          onTap: () => setState(() => _mode = _SetupMode.fresh),
        ),
        const SizedBox(height: 12),
        _ChoiceCard(
          icon: Icons.login_outlined,
          title: 'Mit bestehender Datenbank verbinden',
          subtitle:
              'Jemand hat die Datenbank schon eingerichtet. Du gibst nur die '
              'Zugangsdaten ein und meldest dich an.',
          onTap: () => setState(() => _mode = _SetupMode.existing),
        ),
      ],
    );
  }

  /// Formular je nach gewähltem Modus (mit/ohne ausführlichen Schritten).
  Widget _buildForm(ThemeData theme) {
    final fresh = _mode == _SetupMode.fresh;
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            fresh ? 'Neue eigene Datenbank' : 'Bestehende Datenbank verbinden',
            textAlign: TextAlign.center,
            style: theme.textTheme.headlineSmall,
          ),
          const SizedBox(height: 16),

          if (fresh) ...[
            _StepCard(
              number: '1',
              title: 'Kostenloses Supabase-Projekt anlegen',
              child: const Text(
                'Gehe auf supabase.com, registriere dich kostenlos und '
                'erstelle ein neues Projekt (Region Europa empfohlen). '
                'Warte, bis das Projekt fertig eingerichtet ist.',
              ),
            ),
            _StepCard(
              number: '2',
              title: 'Datenbank einrichten (1 Klick)',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Kopiere das vorbereitete SQL, öffne im Supabase-'
                    'Dashboard den „SQL Editor", füge es ein und klicke '
                    '„Run". Damit werden alle Tabellen, Sicherheitsregeln '
                    'und der Beleg-Speicher angelegt.',
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: _copySetupSql,
                    icon: const Icon(Icons.copy_all_outlined),
                    label: const Text('Einrichtungs-SQL kopieren'),
                  ),
                ],
              ),
            ),
            _StepCard(
              number: '3',
              title: 'Zugangsdaten eintragen',
              child: _credentials(theme),
            ),
          ] else ...[
            _StepCard(
              number: '✓',
              title: 'Zugangsdaten der bestehenden Datenbank',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Trage die Project-URL und den anon/publishable-Schlüssel '
                    'der bereits eingerichteten Datenbank ein. Anmelden kannst '
                    'du dich nur, wenn deine E-Mail dort freigeschaltet ist.',
                  ),
                  const SizedBox(height: 12),
                  _credentials(theme),
                ],
              ),
            ),
          ],

          if (_error != null) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.colorScheme.errorContainer,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.error_outline,
                      color: theme.colorScheme.onErrorContainer),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Verbindung fehlgeschlagen: $_error',
                      style: TextStyle(
                          color: theme.colorScheme.onErrorContainer),
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: _busy ? null : _submit,
            icon: _busy
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.check),
            label: const Text('Verbinden & starten'),
          ),
          if (fresh) ...[
            const SizedBox(height: 8),
            Text(
              'Tipp: Die erste Person, die sich registriert, wird '
              'automatisch Besitzer (Admin mit allen Rechten).',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall,
            ),
          ],
        ],
      ),
    );
  }

  /// Die gemeinsamen URL- + Schlüssel-Felder (in beiden Modi identisch).
  Widget _credentials(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Im Supabase-Dashboard unter „Project Settings" → „Data API" findest '
          'du die Project-URL, unter „API Keys" den „anon"/„publishable"-'
          'Schlüssel. Beide hier einfügen:',
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _url,
          keyboardType: TextInputType.url,
          decoration: const InputDecoration(
            labelText: 'Supabase Project URL',
            hintText: 'https://xxxxxxxx.supabase.co',
            prefixIcon: Icon(Icons.link),
            border: OutlineInputBorder(),
          ),
          validator: (v) {
            final t = (v ?? '').trim();
            if (t.isEmpty) return 'URL eingeben';
            if (!t.startsWith('http')) {
              return 'Muss mit https:// beginnen';
            }
            return null;
          },
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _key,
          minLines: 1,
          maxLines: 3,
          decoration: const InputDecoration(
            labelText: 'anon / publishable Key',
            prefixIcon: Icon(Icons.key_outlined),
            border: OutlineInputBorder(),
          ),
          validator: (v) => (v == null || v.trim().length < 20)
              ? 'Schlüssel eingeben'
              : null,
        ),
      ],
    );
  }
}

/// Auswahlkarte auf dem Erststart-Bildschirm.
class _ChoiceCard extends StatelessWidget {
  const _ChoiceCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: theme.colorScheme.primaryContainer,
                child: Icon(icon, color: theme.colorScheme.onPrimaryContainer),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: theme.textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text(subtitle, style: theme.textTheme.bodySmall),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    );
  }
}

class _StepCard extends StatelessWidget {
  const _StepCard({
    required this.number,
    required this.title,
    required this.child,
  });

  final String number;
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              radius: 14,
              backgroundColor: theme.colorScheme.primary,
              child: Text(number,
                  style: TextStyle(
                      color: theme.colorScheme.onPrimary,
                      fontWeight: FontWeight.bold)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: theme.textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  child,
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
