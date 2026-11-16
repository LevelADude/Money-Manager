import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/account.dart';
import '../../data/models/app_transaction.dart';
import '../../l10n/app_localizations.dart';
import '../../shared/money_text.dart';
import '../accounts/account_providers.dart';
import '../profile/profile_providers.dart';
import '../transactions/transaction_providers.dart';
import '../../core/theme.dart';
import '../../shared/bento.dart';

/// „Wer schuldet wem": teilt die Ausgaben des laufenden Monats gleichmäßig auf
/// alle Personen auf und schlägt einen minimalen Ausgleich vor.
class SettleScreen extends ConsumerWidget {
  const SettleScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accounts = ref.watch(accountsProvider).value ?? const <Account>[];
    final txs =
        ref.watch(allTransactionsProvider).value ?? const <AppTransaction>[];
    final names =
        ref.watch(profileNamesProvider).value ?? const <String, String>{};
    final l = AppLocalizations.of(context);

    String nameOf(String id) =>
        names[id]?.isNotEmpty == true ? names[id]! : l.unknownPerson;

    final ownerOf = {for (final a in accounts) a.id: a.ownerId};
    final members = <String>{
      for (final a in accounts)
        if (a.ownerId != null) a.ownerId!,
    }.toList();

    final now = DateTime.now();
    var total = 0;
    final spent = {for (final m in members) m: 0};
    for (final t in txs) {
      if (t.type != TransactionType.expense) continue;
      if (t.occurredOn.year != now.year || t.occurredOn.month != now.month) {
        continue;
      }
      final owner = ownerOf[t.accountId];
      if (owner == null || !spent.containsKey(owner)) continue;
      spent[owner] = spent[owner]! + t.amountCents;
      total += t.amountCents;
    }

    // Fairer Anteil je Person. Der Ganzzahl-Rest (total % n Cent) wird auf die
    // ersten Personen verteilt, damit die Summe aller Salden exakt 0 ergibt
    // (sonst bliebe ein Rest-Cent im Ausgleichsvorschlag unverteilt).
    final n = members.length;
    final share = n == 0 ? 0 : total ~/ n;
    final remainder = n == 0 ? 0 : total % n;
    final fairShare = <String, int>{
      for (var k = 0; k < n; k++) members[k]: share + (k < remainder ? 1 : 0),
    };
    final balance = {for (final m in members) m: spent[m]! - fairShare[m]!};

    // Minimaler Ausgleich (greedy).
    final plan = <({String from, String to, int amount})>[];
    final bal = Map<String, int>.from(balance);
    final creditors = members.where((m) => bal[m]! > 0).toList()
      ..sort((a, b) => bal[b]!.compareTo(bal[a]!));
    final debtors = members.where((m) => bal[m]! < 0).toList()
      ..sort((a, b) => bal[a]!.compareTo(bal[b]!));
    var i = 0, j = 0;
    while (i < creditors.length && j < debtors.length) {
      final c = creditors[i], d = debtors[j];
      final amt = math.min(bal[c]!, -bal[d]!);
      if (amt > 0) {
        plan.add((from: d, to: c, amount: amt));
        bal[c] = bal[c]! - amt;
        bal[d] = bal[d]! + amt;
      }
      if (bal[c]! <= 0) i++;
      if (bal[d]! >= 0) j++;
    }

    final colors = AppColors.of(context);
    final theme = Theme.of(context);

    Widget hint(IconData icon, String text, {Color? tint}) => BentoTile(
      child: Row(
        children: [
          BentoGlyph(size: 38, tint: tint, child: Icon(icon)),
          const SizedBox(width: 12),
          Expanded(child: Text(text, style: theme.textTheme.bodyMedium)),
        ],
      ),
    );

    Widget initial(String id) => BentoGlyph(
      size: 38,
      child: Text(
        nameOf(id).isNotEmpty ? nameOf(id)[0].toUpperCase() : '?',
        style: theme.textTheme.titleSmall?.copyWith(
          fontWeight: FontWeight.w600,
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );

    Widget section(List<Widget> children) => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: children,
    );

    return Scaffold(
      appBar: AppBar(title: Text(l.settleTitle)),
      body: ListView(
        padding: BentoListView.paddingOf(context),
        children: members.length < 2
            ? [hint(Icons.people_outline, l.settleNeedsTwo)]
            : [
                BentoGrid(
                  cells: [
                    BentoCell(
                      span: 1,
                      wideSpan: 2,
                      child: BentoStat(
                        label: l.sharedExpensesMonth,
                        value: MoneyText(total),
                      ),
                    ),
                    BentoCell(
                      span: 1,
                      wideSpan: 2,
                      child: BentoStat(
                        label: l.fairSharePerPerson,
                        value: MoneyText(share),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: Bento.gap * 2),
                BentoColumns(
                  // Je Seite eine Spalte, damit Überschrift und Kachel auch
                  // schmal zusammenbleiben.
                  left: [
                    section([
                      BentoSectionHeader(label: l.balancesPerPerson),
                      BentoList(
                        children: [
                          for (final m in members)
                            BentoRow(
                              leading: initial(m),
                              title: Text(nameOf(m)),
                              subtitle: MoneyText(
                                spent[m]!,
                                prefix: l.spentPrefix,
                              ),
                              trailing: MoneyText(
                                balance[m]!,
                                prefix: balance[m]! > 0 ? '+' : '',
                                style: TextStyle(
                                  color: balance[m]! > 0
                                      ? colors.income
                                      : balance[m]! < 0
                                      ? colors.expense
                                      : null,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ]),
                  ],
                  right: [
                    section([
                      BentoSectionHeader(label: l.settleSuggestion),
                      if (plan.isEmpty)
                        hint(Icons.check, l.allSettled, tint: colors.income)
                      else
                        BentoList(
                          children: [
                            for (final p in plan)
                              BentoRow(
                                leading: const BentoGlyph(
                                  size: 38,
                                  child: Icon(Icons.arrow_forward),
                                ),
                                title: Text(
                                  '${nameOf(p.from)} → ${nameOf(p.to)}',
                                ),
                                trailing: MoneyText(p.amount),
                              ),
                          ],
                        ),
                    ]),
                  ],
                ),
                const SizedBox(height: Bento.gap),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: Text(l.settleHint, style: Bento.sub(context)),
                ),
              ],
      ),
    );
  }
}
