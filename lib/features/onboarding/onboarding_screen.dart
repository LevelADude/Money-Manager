import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../config/app_config.dart';
import '../../shared/responsive.dart';

/// Erststart-Einrichtung: fragt Supabase-URL + Schlüssel ab und erklärt in
/// einfachen Schritten, wie eine fremde Person ihre eigene Datenbank verbindet.
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
      appBar: AppBar(title: const Text('Einrichtung')),
      body: MaxWidthBox(
        maxWidth: 640,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Icon(Icons.cloud_sync_outlined,
                    size: 48, color: theme.colorScheme.primary),
                const SizedBox(height: 12),
                Text('Mit deiner Datenbank verbinden',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.headlineSmall),
                const SizedBox(height: 8),
                Text(
                  'Money Manager speichert deine Daten in deinem eigenen, '
                  'kostenlosen Supabase-Projekt. Folge den drei Schritten – '
                  'Programmierkenntnisse sind nicht nötig.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium,
                ),
                const SizedBox(height: 20),

                // Schritt 1
                _StepCard(
                  number: '1',
                  title: 'Kostenloses Supabase-Projekt anlegen',
                  child: const Text(
                    'Gehe auf supabase.com, registriere dich kostenlos und '
                    'erstelle ein neues Projekt (Region Europa empfohlen). '
                    'Warte, bis das Projekt fertig eingerichtet ist.',
                  ),
                ),

                // Schritt 2
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

                // Schritt 3
                _StepCard(
                  number: '3',
                  title: 'Zugangsdaten eintragen',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text(
                        'Im Supabase-Dashboard unter „Project Settings" → '
                        '„Data API" findest du die Project-URL, unter „API Keys" '
                        'den „anon"/„publishable"-Schlüssel. Beide hier einfügen:',
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
                  ),
                ),

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
                const SizedBox(height: 8),
                Text(
                  'Tipp: Die erste Person, die sich registriert, wird '
                  'automatisch Administrator.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
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
