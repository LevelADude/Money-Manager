import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/models/account.dart';
import '../../l10n/app_localizations.dart';
import '../../shared/money_text.dart';
import '../accounts/account_providers.dart';
import '../currency/currency_providers.dart';
import '../profile/profile_providers.dart';
import 'reservation_providers.dart';
import 'reservation_tile.dart';

/// Übersicht aller Reservierungen, nach Konto gruppiert.
class ReservationsScreen extends ConsumerWidget {
  const ReservationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final reservations = ref.watch(reservationsProvider);
    final accounts = ref.watch(accountsProvider).value ?? const <Account>[];
    final manageable = {
      for (final a in ref.watch(manageableAccountsProvider)) a.id,
    };
    final readOnly = ref.watch(isReadOnlyProvider).value ?? false;
    final convert = ref.watch(converterProvider);
    final overReserved = ref.watch(overReservedAccountsProvider);
    final byId = {for (final a in accounts) a.id: a};

    var totalBase = 0;
    for (final r in reservations) {
      final a = byId[r.accountId];
      if (a != null) totalBase += convert(r.amountCents, a.currency);
    }

    // Gruppen in der Konten-Reihenfolge.
    final groups = [
      for (final a in accounts)
        (
          account: a,
          items: reservations.where((r) => r.accountId == a.id).toList(),
        ),
    ].where((g) => g.items.isNotEmpty).toList();

    return Scaffold(
      appBar: AppBar(title: Text(l.reservations)),
      floatingActionButton: (readOnly || manageable.isEmpty)
          ? null
          : FloatingActionButton.extended(
              onPressed: () => context.go('/more/reservations/new'),
              icon: const Icon(Icons.add),
              label: Text(l.reserveAction),
            ),
      body: reservations.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      l.noReservations,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    Text(l.noReservationsHint, textAlign: TextAlign.center),
                  ],
                ),
              ),
            )
          : ListView(
              padding: const EdgeInsets.only(bottom: 88),
              children: [
                Card(
                  margin: const EdgeInsets.all(12),
                  child: ListTile(
                    leading: const Icon(Icons.bookmarks_outlined),
                    title: Text(l.reservedLabel),
                    subtitle: Text(l.allAccounts),
                    trailing: MoneyText(
                      totalBase,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                for (final g in groups) ...[
                  ListTile(
                    dense: true,
                    title: Text(
                      g.account.name,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    subtitle: overReserved.contains(g.account.id)
                        ? Text(
                            l.overReservedWarning,
                            style: TextStyle(color: Colors.red.shade700),
                          )
                        : null,
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => context.go('/account/${g.account.id}'),
                  ),
                  for (final r in g.items)
                    ReservationTile(
                      reservation: r,
                      currency: g.account.currency,
                      canManage: !readOnly && manageable.contains(r.accountId),
                      onEdit: () => context.go('/more/reservations/${r.id}'),
                    ),
                  const Divider(height: 1),
                ],
              ],
            ),
    );
  }
}
