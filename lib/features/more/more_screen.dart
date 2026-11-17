import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../l10n/app_localizations.dart';
import '../../shared/bento.dart';
import '../../shared/responsive.dart';
import '../auth/auth_providers.dart';
import '../profile/profile_providers.dart';

/// "Mehr"-Tab: Sammelmenü für Funktionen außerhalb der Haupt-Tabs, als
/// gruppierte Kacheln (schmal untereinander, breit in zwei Spalten).
class MoreScreen extends ConsumerWidget {
  const MoreScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final email =
        ref.watch(supabaseClientProvider).auth.currentUser?.email ?? '';
    final isAdmin = ref.watch(isAdminProvider).value ?? false;
    final l = AppLocalizations.of(context);

    Widget tile(IconData icon, String title, String route) => BentoRow(
      leading: BentoGlyph(size: 36, child: Icon(icon)),
      title: Text(title),
      trailing: Icon(
        Icons.chevron_right,
        size: 20,
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
      onTap: () => context.go(route),
    );

    // Gruppen nach Zweck: Finden, Auswerten/Planen, Ziele und Schulden,
    // Automatik, Daten, Konto und App.
    final find = BentoList(
      children: [
        tile(Icons.search, l.moreSearch, '/more/search'),
        tile(Icons.insights_outlined, l.moreInsights, '/more/insights'),
        tile(Icons.notifications_outlined, l.moreReminders, '/more/reminders'),
        tile(Icons.history, l.moreActivity, '/more/activity'),
      ],
    );
    final plan = BentoList(
      children: [
        tile(Icons.savings_outlined, l.moreBudgets, '/more/budgets'),
        tile(Icons.functions, l.customSums, '/account/groups'),
        tile(Icons.calculate_outlined, l.morePlanning, '/more/planning'),
        tile(Icons.tune, l.moreSimulator, '/more/simulator'),
        tile(Icons.event_note_outlined, l.moreCashflow, '/more/cashflow'),
      ],
    );
    final goals = BentoList(
      children: [
        tile(Icons.luggage_outlined, l.moreProjects, '/more/projects'),
        tile(Icons.bookmarks_outlined, l.reservations, '/more/reservations'),
        tile(Icons.flag_outlined, l.moreGoals, '/more/goals'),
        tile(Icons.trending_down, l.moreDebts, '/more/debts'),
        tile(Icons.handshake_outlined, l.moreSettle, '/more/settle'),
      ],
    );
    final automation = BentoList(
      children: [
        tile(Icons.repeat, l.moreRecurring, '/more/recurring'),
        tile(Icons.autorenew, l.moreSubscriptions, '/more/subscriptions'),
        tile(Icons.label_outline, l.moreCategories, '/more/categories'),
        tile(Icons.bolt_outlined, l.moreRules, '/more/rules'),
      ],
    );
    final data = BentoList(
      children: [
        tile(Icons.download_outlined, l.moreExport, '/more/export'),
        tile(Icons.upload_file_outlined, l.moreImport, '/more/import'),
        tile(Icons.delete_outline, l.moreTrash, '/more/trash'),
        tile(Icons.backup_outlined, l.moreBackup, '/more/backup'),
        tile(Icons.inventory_2_outlined, l.archiveMenu, '/more/archive'),
      ],
    );
    final app = BentoList(
      children: [
        tile(Icons.palette_outlined, l.moreSettings, '/more/settings'),
        tile(Icons.account_circle_outlined, l.moreProfile, '/more/profile'),
        tile(Icons.people_alt_outlined, l.moreSharing, '/more/sharing'),
        if (isAdmin)
          tile(Icons.admin_panel_settings_outlined, l.moreAdmin, '/more/admin'),
      ],
    );

    return Scaffold(
      appBar: AppBar(title: Text(l.navMore)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          Bento.margin,
          4,
          Bento.margin,
          16,
        ).withBarInset(context),
        children: [
          BentoColumns(
            left: [find, goals, data],
            right: [plan, automation, app],
          ),
          if (email.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(6, 16, 6, 0),
              child: Text(l.signedInAs(email), style: Bento.sub(context)),
            ),
        ],
      ),
    );
  }
}
