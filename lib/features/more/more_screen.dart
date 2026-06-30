import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../l10n/app_localizations.dart';
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
    final l = AppLocalizations.of(context);

    Widget tile(IconData icon, String title, String route) => ListTile(
      leading: Icon(icon),
      title: Text(title),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => context.go(route),
    );

    return Scaffold(
      appBar: AppBar(title: Text(l.navMore)),
      body: ListView(
        children: [
          tile(Icons.search, l.moreSearch, '/more/search'),
          tile(Icons.insights_outlined, l.moreInsights, '/more/insights'),
          tile(
            Icons.notifications_outlined,
            l.moreReminders,
            '/more/reminders',
          ),
          tile(Icons.history, l.moreActivity, '/more/activity'),
          tile(Icons.savings_outlined, l.moreBudgets, '/more/budgets'),
          tile(Icons.calculate_outlined, l.morePlanning, '/more/planning'),
          tile(Icons.tune, l.moreSimulator, '/more/simulator'),
          tile(Icons.luggage_outlined, l.moreProjects, '/more/projects'),
          tile(Icons.event_note_outlined, l.moreCashflow, '/more/cashflow'),
          tile(Icons.flag_outlined, l.moreGoals, '/more/goals'),
          tile(Icons.trending_down, l.moreDebts, '/more/debts'),
          tile(Icons.handshake_outlined, l.moreSettle, '/more/settle'),
          tile(Icons.repeat, l.moreRecurring, '/more/recurring'),
          tile(Icons.autorenew, l.moreSubscriptions, '/more/subscriptions'),
          tile(Icons.label_outline, l.moreCategories, '/more/categories'),
          tile(Icons.bolt_outlined, l.moreRules, '/more/rules'),
          tile(Icons.download_outlined, l.moreExport, '/more/export'),
          tile(Icons.upload_file_outlined, l.moreImport, '/more/import'),
          const Divider(),
          tile(Icons.delete_outline, l.moreTrash, '/more/trash'),
          tile(Icons.backup_outlined, l.moreBackup, '/more/backup'),
          tile(Icons.inventory_2_outlined, l.archiveMenu, '/more/archive'),
          tile(Icons.palette_outlined, l.moreSettings, '/more/settings'),
          tile(Icons.account_circle_outlined, l.moreProfile, '/more/profile'),
          tile(Icons.people_alt_outlined, l.moreSharing, '/more/sharing'),
          if (isAdmin)
            tile(
              Icons.admin_panel_settings_outlined,
              l.moreAdmin,
              '/more/admin',
            ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              email.isEmpty ? '' : l.signedInAs(email),
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ],
      ),
    );
  }
}
