import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../shared/app_bar_actions.dart';
import '../../data/models/account.dart';
import '../../data/models/account_group.dart';
import '../../l10n/app_localizations.dart';
import '../../shared/bento.dart';
import '../../shared/category_icons.dart';
import '../../shared/data_refresh.dart';
import '../../shared/hide_amounts_toggle.dart';
import '../../shared/mini_line_chart.dart';
import '../../shared/money.dart';
import '../../shared/money_text.dart';
import '../../shared/multi_currency_text.dart';
import '../../shared/responsive.dart';
import '../auth/auth_providers.dart';
import '../currency/currency_providers.dart';
import '../profile/profile_providers.dart';
import '../profile/profile_switcher.dart';
import '../recurring/recurring_providers.dart';
import '../reminders/reminders_providers.dart';
import '../reservations/reservation_providers.dart';
import '../reservations/reserved_hint.dart';
import '../settings/settings_providers.dart';
import '../statistics/statistics_providers.dart';
import '../sharing/account_member_providers.dart';
import '../transactions/person_filter.dart';
import '../transactions/transaction_providers.dart';
import 'account_providers.dart';
import '../../core/theme.dart';

/// "Konten"-Tab: Gesamtvermögen + Konten, nach Kontokategorie gruppiert
/// (mit Summe je Kategorie).
class AccountsScreen extends ConsumerWidget {
  const AccountsScreen({super.key});

  // Anzeige-Reihenfolge der Kontotypen (Vermögenswerte zuerst, Schulden zuletzt).
  static const List<AccountType> _order = [
    AccountType.bank,
    AccountType.cash,
    AccountType.savings,
    AccountType.wallet,
    AccountType.investment,
    AccountType.other,
    AccountType.creditCard,
    AccountType.loan,
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Fällige Daueraufträge beim App-Start einmalig erzeugen.
    ref.watch(recurringGenerationProvider);
    // Fällige wiederkehrende Rücklagen fortschreiben.
    ref.watch(reservationTopupProvider);

    final accountsAsync = ref.watch(accountsProvider);
    final personFilter = ref.watch(personFilterProvider);
    final myId = ref.watch(currentUserIdProvider);
    // Eigene Konten kann man nur in der Eigen-/Gesamtansicht anlegen.
    final canAddAccount = personFilter == null || personFilter == myId;
    final readOnly = ref.watch(isReadOnlyProvider).value ?? false;
    final convert = ref.watch(converterProvider);
    // Alle Salden auf einmal (ein Durchlauf über die Buchungen, von Riverpod
    // gecacht) statt pro Konto erneut über sämtliche Buchungen zu laufen.
    final balances = ref.watch(accountBalancesProvider);
    // Groß angezeigter Wert je Konto (verfügbar oder gesamt, laut Einstellung).
    final primaryBalances = ref.watch(primaryBalancesProvider);
    final reservedMap = ref.watch(reservedByAccountProvider);
    final overReserved = ref.watch(overReservedAccountsProvider);
    final showAvailable = ref.watch(
      settingsProvider.select((s) => s.showAvailable),
    );
    final memberNames =
        ref.watch(profileNamesProvider).value ?? const <String, String>{};
    final l = AppLocalizations.of(context);

    int balanceOf(Account a) => balances[a.id] ?? 0;
    int primaryOf(Account a) => primaryBalances[a.id] ?? 0;

    return Scaffold(
      appBar: AppBar(
        title: Text(l.navAccounts),
        actions: responsiveActions(
          context,
          primary: [
            const HideAmountsToggle(),
            const ProfileSwitcher(),
            Builder(
              builder: (context) {
                final count = ref.watch(remindersProvider).length;
                return IconButton(
                  tooltip: l.moreReminders,
                  icon: Badge(
                    isLabelVisible: count > 0,
                    label: Text('$count'),
                    child: const Icon(Icons.notifications_outlined),
                  ),
                  onPressed: () => context.go('/more/reminders'),
                );
              },
            ),
          ],
          secondary: [
            (
              icon: Icons.refresh,
              label: l.refresh,
              onPressed: () {
                refreshAllData(ref);
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(SnackBar(content: Text(l.refreshed)));
              },
            ),
            (
              icon: Icons.search,
              label: l.moreSearch,
              onPressed: () => context.go('/more/search'),
            ),
            (
              icon: Icons.swap_vert,
              label: l.sortAccounts,
              onPressed: () => context.go('/account/reorder'),
            ),
          ],
        ),
      ),
      floatingActionButton: (readOnly || !canAddAccount)
          ? null
          : FloatingActionButton.extended(
              onPressed: () => context.go('/account/new'),
              icon: const Icon(Icons.add),
              label: Text(l.accountFab),
            ),
      body: accountsAsync.when(
        skipLoadingOnReload: true,
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text(l.errorWith(e))),
        data: (allAccounts) {
          // Konten der gewählten Person inkl. geteilter Konten (null = alle).
          final accounts = ref.watch(personFilteredAccountsProvider);
          final membersByAccount = ref.watch(membersByAccountProvider);
          if (accounts.isEmpty) {
            return Center(child: Text(l.noAccounts));
          }
          final byType = <AccountType, List<Account>>{};
          for (final a in accounts) {
            byType.putIfAbsent(a.type, () => []).add(a);
          }

          final sums = <Widget>[];

          // Vermögen je Person nur in der Gesamtansicht („Alle Personen").
          final owners = <String>{
            for (final a in accounts)
              if (a.ownerId != null) a.ownerId!,
          }.toList();
          if (personFilter == null && owners.length > 1) {
            final entries = [
              for (final o in owners)
                (
                  name: memberNames[o]?.isNotEmpty == true
                      ? memberNames[o]!
                      : l.unknownPerson,
                  cents: primaryAmount(
                    ref.watch(netWorthProvider(o)),
                    ref.watch(reservedNetWorthProvider(o)),
                    showAvailable,
                  ),
                ),
            ]..sort((a, b) => b.cents.compareTo(a.cents));
            sums.add(_PerPersonCard(entries: entries));
          }

          // Eigene Custom-Summen (nur in der Eigen-/Gesamtansicht).
          if (personFilter == null || personFilter == myId) {
            final groupTotals = ref.watch(accountGroupTotalsProvider);
            if (groupTotals.isNotEmpty) {
              sums.add(_CustomSumsCard(entries: groupTotals));
            }
          }

          final hero = _NetWorthCard(
            totalCents: ref.watch(netWorthProvider(personFilter)),
            reservedCents: ref.watch(reservedNetWorthProvider(personFilter)),
          );

          // Je Kontotyp eine Listen-Kachel mit Überschrift und Zwischensumme.
          final groups = <Widget>[];
          for (final type in _order) {
            final group = byType[type];
            if (group == null || group.isEmpty) continue;
            final subtotal = group.fold<int>(
              0,
              (s, a) => s + convert(primaryOf(a), a.currency),
            );
            groups.add(
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  _CategoryHeader(label: l.accountType(type), cents: subtotal),
                  BentoList(
                    children: [
                      for (final a in group)
                        _AccountTile(
                          account: a,
                          balanceCents: balanceOf(a),
                          reservedCents: reservedMap[a.id] ?? 0,
                          overReserved: overReserved.contains(a.id),
                          currency: a.currency,
                          ownerName: memberNames[a.ownerId] ?? '',
                          shared: membersByAccount[a.id]?.isNotEmpty ?? false,
                          onTap: () => context.go('/account/${a.id}'),
                          onEdit: () => context.go('/account/${a.id}/edit'),
                          onArchive: () async {
                            await ref
                                .read(accountRepositoryProvider)
                                .setArchived(id: a.id, archived: !a.archived);
                            ref.invalidate(accountsProvider);
                          },
                          onDelete: () => _confirmDelete(context, ref, a),
                        ),
                    ],
                  ),
                ],
              ),
            );
          }

          return LayoutBuilder(
            builder: (context, box) {
              final wide =
                  box.maxWidth - 2 * Bento.margin >= Bento.wideBreakpoint;
              const gap = SizedBox(height: Bento.gap);
              return ListView(
                // Unten Platz für den „Konto"-Knopf über der Glas-Leiste.
                padding: const EdgeInsets.fromLTRB(
                  Bento.margin,
                  4,
                  Bento.margin,
                  88,
                ).withBarInset(context),
                children: [
                  if (wide && sums.isNotEmpty)
                    // Breit: Gesamtsaldo links, Summen-Kacheln rechts daneben.
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: hero),
                        const SizedBox(width: Bento.gap),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              for (var i = 0; i < sums.length; i++) ...[
                                if (i > 0) gap,
                                sums[i],
                              ],
                            ],
                          ),
                        ),
                      ],
                    )
                  else ...[
                    hero,
                    for (final s in sums) ...[gap, s],
                  ],
                  const SizedBox(height: 20),
                  if (wide)
                    BentoColumns(
                      gap: 20,
                      left: [
                        for (var i = 0; i < groups.length; i += 2) groups[i],
                      ],
                      right: [
                        for (var i = 1; i < groups.length; i += 2) groups[i],
                      ],
                    )
                  else
                    for (var i = 0; i < groups.length; i++) ...[
                      if (i > 0) const SizedBox(height: 20),
                      groups[i],
                    ],
                ],
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    Account a,
  ) async {
    final l = AppLocalizations.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l.deleteAccountTitle(a.name)),
        content: Text(l.deleteAccountBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l.delete),
          ),
        ],
      ),
    );
    if (ok == true) {
      await ref.read(accountRepositoryProvider).deleteAccount(a.id);
      ref.invalidate(accountsProvider);
      ref.invalidate(allTransactionsProvider);
    }
  }
}

/// Große Kachel: Gesamtvermögen mit Verlauf der letzten 12 Monate.
class _NetWorthCard extends ConsumerWidget {
  const _NetWorthCard({required this.totalCents, required this.reservedCents});

  final int totalCents;
  final int reservedCents;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final c = AppColors.of(context);
    final showAvailable = ref.watch(
      settingsProvider.select((s) => s.showAvailable),
    );
    // Aus den ohnehin geladenen Buchungen berechnet (keine weitere Abfrage).
    final history = ref.watch(netWorthHistoryProvider);
    final hasTrend =
        history.length >= 2 && history.any((h) => h.cents != history[0].cents);
    final delta = hasTrend ? history.last.cents - history.first.cents : 0;
    final primary = primaryAmount(totalCents, reservedCents, showAvailable);
    return BentoTile(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(18, 18, 18, hasTrend ? 0 : 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        showAvailable && reservedCents != 0
                            ? l.availableNetWorth
                            : l.netWorth,
                        style: Bento.label(context),
                      ),
                    ),
                    if (hasTrend)
                      BentoChip(
                        icon: delta >= 0
                            ? Icons.trending_up
                            : Icons.trending_down,
                        child: MoneyText(delta, prefix: delta >= 0 ? '+' : ''),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: MoneyText(
                    primary,
                    style: Bento.number(
                      context,
                      size: 40,
                    ).copyWith(color: primary < 0 ? c.expense : null),
                  ),
                ),
                ReservedHint(
                  totalCents: totalCents,
                  reservedCents: reservedCents,
                  style: Bento.sub(context),
                ),
                MultiCurrencyText(primary, style: Bento.sub(context)),
                if (hasTrend)
                  Text(l.netWorthTrend12, style: Bento.sub(context)),
              ],
            ),
          ),
          if (hasTrend)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: MiniLineChart(
                values: [for (final h in history) h.cents],
                color: Theme.of(context).colorScheme.primary,
                height: 84,
              ),
            ),
        ],
      ),
    );
  }
}

/// Zeile „Name … Betrag" in einer Summen-Kachel.
class _SumLine extends StatelessWidget {
  const _SumLine({required this.name, required this.cents});

  final String name;
  final int cents;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(
        children: [
          Expanded(child: Text(name, overflow: TextOverflow.ellipsis)),
          const SizedBox(width: 12),
          MoneyText(
            cents,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: cents < 0 ? AppColors.of(context).expense : null,
            ),
          ),
        ],
      ),
    );
  }
}

class _PerPersonCard extends StatelessWidget {
  const _PerPersonCard({required this.entries});

  final List<({String name, int cents})> entries;

  @override
  Widget build(BuildContext context) {
    return BentoTile(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            AppLocalizations.of(context).wealthPerPerson,
            style: Bento.label(context),
          ),
          for (final e in entries) _SumLine(name: e.name, cents: e.cents),
        ],
      ),
    );
  }
}

class _CustomSumsCard extends StatelessWidget {
  const _CustomSumsCard({required this.entries});

  final List<({AccountGroup group, int cents})> entries;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return BentoTile(
      onTap: () => context.go('/account/groups'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(child: Text(l.customSums, style: Bento.label(context))),
              Icon(
                Icons.tune,
                size: 18,
                color: Theme.of(context).colorScheme.primary,
              ),
            ],
          ),
          for (final e in entries) _SumLine(name: e.group.name, cents: e.cents),
        ],
      ),
    );
  }
}

class _CategoryHeader extends StatelessWidget {
  const _CategoryHeader({required this.label, required this.cents});

  final String label;
  final int cents;

  @override
  Widget build(BuildContext context) {
    return BentoSectionHeader(
      label: label,
      trailing: MoneyText(
        cents,
        style: TextStyle(
          color: cents < 0 ? AppColors.of(context).expense : null,
        ),
      ),
    );
  }
}

class _AccountTile extends ConsumerWidget {
  const _AccountTile({
    required this.account,
    required this.balanceCents,
    required this.reservedCents,
    required this.overReserved,
    required this.currency,
    required this.ownerName,
    required this.shared,
    required this.onTap,
    required this.onEdit,
    required this.onArchive,
    required this.onDelete,
  });

  final Account account;
  final int balanceCents;
  final int reservedCents;
  final bool overReserved;
  final String currency;
  final String ownerName;
  final bool shared;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onArchive;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final showAvailable = ref.watch(
      settingsProvider.select((s) => s.showAvailable),
    );
    final primary = primaryAmount(balanceCents, reservedCents, showAvailable);
    final negative = primary < 0;
    final subtitle = [
      if (ownerName.isNotEmpty) ownerName,
      if (shared) l.sharedLabel,
      if (account.archived) l.archivedLabel,
    ].join('  ·  ');
    return BentoRow(
      onTap: onTap,
      padding: const EdgeInsets.fromLTRB(14, 9, 2, 9),
      leading: BentoGlyph(
        child: Icon(iconForAccountType(accountTypeToDb(account.type))),
      ),
      title: Text(account.name),
      subtitle: subtitle.isEmpty ? null : Text(subtitle),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (overReserved)
            Padding(
              padding: const EdgeInsets.only(right: 6),
              child: Tooltip(
                message: l.overReservedWarning,
                child: Icon(
                  Icons.warning_amber_rounded,
                  size: 18,
                  color: AppColors.of(context).expense,
                ),
              ),
            ),
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              MoneyText(
                primary,
                currency: currency,
                style: TextStyle(
                  color: negative ? AppColors.of(context).expense : null,
                ),
              ),
              _CompactReservedHint(
                totalCents: balanceCents,
                reservedCents: reservedCents,
                currency: currency,
              ),
            ],
          ),
          PopupMenuButton<String>(
            iconColor: Theme.of(context).colorScheme.onSurfaceVariant,
            onSelected: (v) {
              switch (v) {
                case 'edit':
                  onEdit();
                case 'archive':
                  onArchive();
                case 'delete':
                  onDelete();
              }
            },
            itemBuilder: (ctx) => [
              PopupMenuItem(
                value: 'edit',
                child: ListTile(
                  leading: const Icon(Icons.edit_outlined),
                  title: Text(l.edit),
                ),
              ),
              PopupMenuItem(
                value: 'archive',
                child: ListTile(
                  leading: Icon(
                    account.archived
                        ? Icons.unarchive_outlined
                        : Icons.archive_outlined,
                  ),
                  title: Text(account.archived ? l.activate : l.archive),
                ),
              ),
              PopupMenuItem(
                value: 'delete',
                child: ListTile(
                  leading: const Icon(Icons.delete_outline),
                  title: Text(l.delete),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Kurzform für Kontokacheln: zeigt klein den jeweils anderen Wert
/// (Gesamt bzw. Verfügbar), damit die Zeile schmal bleibt.
class _CompactReservedHint extends ConsumerWidget {
  const _CompactReservedHint({
    required this.totalCents,
    required this.reservedCents,
    required this.currency,
  });

  final int totalCents;
  final int reservedCents;
  final String currency;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hide = ref.watch(settingsProvider.select((s) => s.hideAmounts));
    final showAvailable = ref.watch(
      settingsProvider.select((s) => s.showAvailable),
    );
    if (hide || reservedCents == 0) return const SizedBox.shrink();
    final l = AppLocalizations.of(context);
    final other = showAvailable ? totalCents : totalCents - reservedCents;
    final label = showAvailable ? l.totalShort : l.available;
    return Text(
      '$label ${formatMoney(other, currency)}',
      style: Bento.sub(context).copyWith(fontSize: 12),
    );
  }
}
