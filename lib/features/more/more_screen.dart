import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../auth/auth_providers.dart';
import '../profile/profile_providers.dart';

/// "Mehr"-Tab: Sammelmenü für Funktionen außerhalb der Haupt-Tabs.
class MoreScreen extends ConsumerWidget {
  const MoreScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final email =
        ref.watch(supabaseClientProvider).auth.currentUser?.email ?? '';
    final isAdmin = ref.watch(isAdminProvider).asData?.value ?? false;

    Widget tile(IconData icon, String title, String route) => ListTile(
          leading: Icon(icon),
          title: Text(title),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => context.go(route),
        );

    return Scaffold(
      appBar: AppBar(title: const Text('Mehr')),
      body: ListView(
        children: [
          tile(Icons.search, 'Suche', '/more/search'),
          tile(Icons.history, 'Aktivität', '/more/activity'),
          tile(Icons.savings_outlined, 'Budgets', '/more/budgets'),
          tile(Icons.calculate_outlined, 'Verfügbar & Fixkosten',
              '/more/planning'),
          tile(Icons.event_note_outlined, 'Cashflow-Kalender',
              '/more/cashflow'),
          tile(Icons.flag_outlined, 'Sparziele & Töpfe', '/more/goals'),
          tile(Icons.trending_down, 'Schulden & Kredite', '/more/debts'),
          tile(Icons.handshake_outlined, 'Ausgleich (wer schuldet wem)',
              '/more/settle'),
          tile(Icons.repeat, 'Daueraufträge', '/more/recurring'),
          tile(Icons.label_outline, 'Kategorien', '/more/categories'),
          tile(Icons.download_outlined, 'Export (CSV)', '/more/export'),
          const Divider(),
          tile(Icons.delete_outline, 'Papierkorb', '/more/trash'),
          tile(Icons.backup_outlined, 'Backup & Wiederherstellung',
              '/more/backup'),
          tile(Icons.palette_outlined, 'Einstellungen', '/more/settings'),
          tile(Icons.account_circle_outlined, 'Profil', '/more/profile'),
          if (isAdmin)
            tile(Icons.admin_panel_settings_outlined, 'Verwaltung (Admin)',
                '/more/admin'),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              email.isEmpty ? '' : 'Angemeldet als $email',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ],
      ),
    );
  }
}
