// Design-Vorschau ohne Login und ohne Supabase.
//
// Zeigt das echte Theme und die echte Glas-Navigation mit Beispielinhalt, um
// Paletten und Bausteine im Browser zu prüfen:
//   flutter run -d web-server --web-port 5175 -t lib/dev_preview.dart
// Wird von der App nicht importiert und landet daher nicht im Release-Build.
import 'package:flutter/material.dart';

import 'core/main_scaffold.dart';
import 'core/theme.dart';
import 'shared/responsive.dart';

void main() => runApp(const _PreviewApp());

class _PreviewApp extends StatefulWidget {
  const _PreviewApp();

  @override
  State<_PreviewApp> createState() => _PreviewAppState();
}

class _PreviewAppState extends State<_PreviewApp> {
  AppPalette _palette = AppPalette.sage;
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.themeFor(_palette),
      home: Builder(
        builder: (context) {
          const items = [
            (
              icon: Icons.account_balance_wallet_outlined,
              active: Icons.account_balance_wallet,
              label: 'Konten',
            ),
            (
              icon: Icons.receipt_long_outlined,
              active: Icons.receipt_long,
              label: 'Buchungen',
            ),
            (
              icon: Icons.bar_chart_outlined,
              active: Icons.bar_chart,
              label: 'Statistik',
            ),
            (icon: Icons.menu, active: Icons.menu, label: 'Mehr'),
          ];
          final page = _SamplePage(
            title: items[_tab].label,
            palette: _palette,
            onPalette: (p) => setState(() => _palette = p),
          );
          if (context.isWide) {
            return Scaffold(
              body: SafeArea(
                child: Row(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(14, 14, 4, 14),
                      child: GlassRail(
                        items: items,
                        current: _tab,
                        onSelect: (i) => setState(() => _tab = i),
                        onAdd: () {},
                        addLabel: 'Buchung',
                      ),
                    ),
                    Expanded(child: MaxWidthBox(child: page)),
                  ],
                ),
              ),
            );
          }
          return Scaffold(
            body: page,
            bottomNavigationBar: SafeArea(
              minimum: const EdgeInsets.fromLTRB(14, 8, 14, 14),
              child: Row(
                children: [
                  Expanded(
                    child: GlassTabBar(
                      items: items,
                      current: _tab,
                      onSelect: (i) => setState(() => _tab = i),
                    ),
                  ),
                  const SizedBox(width: 12),
                  GlassAddButton(onTap: () {}, label: 'Buchung'),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _SamplePage extends StatelessWidget {
  const _SamplePage({
    required this.title,
    required this.palette,
    required this.onPalette,
  });

  final String title;
  final AppPalette palette;
  final ValueChanged<AppPalette> onPalette;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final c = AppColors.of(context);
    Widget row(
      String emoji,
      String name,
      String sub,
      String amount,
      bool pos,
    ) => ListTile(
      leading: CircleAvatar(
        backgroundColor: c.chip,
        child: Text(emoji, style: const TextStyle(fontSize: 20)),
      ),
      title: Text(name),
      subtitle: Text(sub),
      trailing: Text(
        amount,
        style: t.textTheme.titleMedium?.copyWith(color: pos ? c.income : null),
      ),
      onTap: () {},
    );
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: [
          IconButton(onPressed: () {}, icon: const Icon(Icons.search)),
          IconButton(onPressed: () {}, icon: const Icon(Icons.swap_vert)),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => showModalBottomSheet<void>(
          context: context,
          useRootNavigator: true,
          builder: (_) => const SizedBox(
            height: 220,
            child: Center(child: Text('Beispiel-Sheet')),
          ),
        ),
        icon: const Icon(Icons.add),
        label: const Text('Konto'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(12, 4, 12, 96),
        children: [
          SegmentedButton<AppPalette>(
            segments: const [
              ButtonSegment(value: AppPalette.sage, label: Text('Salbei')),
              ButtonSegment(value: AppPalette.emerald, label: Text('Smaragd')),
              ButtonSegment(value: AppPalette.dark, label: Text('Dunkel')),
            ],
            selected: {palette},
            onSelectionChanged: (s) => onPalette(s.first),
          ),
          const SizedBox(height: 8),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Gesamtvermögen',
                    style: t.textTheme.bodySmall?.copyWith(
                      color: t.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  Text('12.480,35 €', style: t.textTheme.displaySmall),
                  const SizedBox(height: 10),
                  const LinearProgressIndicator(value: .68),
                ],
              ),
            ),
          ),
          Card(
            child: Column(
              children: [
                row('🏦', 'Girokonto', 'Hauptkonto', '2.310,20 €', false),
                const Divider(),
                row('💰', 'Sparkonto', 'Tagesgeld', '9.400,00 €', false),
                const Divider(),
                row('💼', 'Gehalt November', 'Einkommen', '+2.950,00 €', true),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton(onPressed: () {}, child: const Text('Speichern')),
              OutlinedButton(onPressed: () {}, child: const Text('Abbrechen')),
              TextButton(onPressed: () {}, child: const Text('Mehr')),
              FilterChip(
                label: const Text('Ausgaben'),
                selected: true,
                onSelected: (_) {},
              ),
              FilterChip(label: const Text('Einnahmen'), onSelected: (_) {}),
              ElevatedButton(
                onPressed: () => showDialog<void>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('Buchung löschen?'),
                    content: const Text(
                      'Das lässt sich nicht rückgängig machen.',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx),
                        child: const Text('Abbrechen'),
                      ),
                      FilledButton(
                        onPressed: () => Navigator.pop(ctx),
                        child: const Text('Löschen'),
                      ),
                    ],
                  ),
                ),
                child: const Text('Dialog'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const TextField(
            decoration: InputDecoration(
              labelText: 'Notiz',
              hintText: 'Optional',
            ),
          ),
          const SizedBox(height: 8),
          SwitchListTile(
            value: true,
            onChanged: (_) {},
            title: const Text('Beträge verbergen'),
          ),
          for (var i = 0; i < 6; i++)
            Card(
              child: row(
                '🛒',
                'REWE City',
                'Lebensmittel · Girokonto',
                '−42,18 €',
                false,
              ),
            ),
        ],
      ),
    );
  }
}
