import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart' hide TextDirection;

import '../../data/models/app_transaction.dart';
import '../../data/models/savings_goal.dart';
import '../../l10n/app_localizations.dart';
import '../../shared/money.dart';
import '../../shared/money_text.dart';
import '../transactions/transaction_providers.dart';
import 'savings_providers.dart';
import '../../core/theme.dart';
import '../../shared/bento.dart';

/// Sparziele: Zielbetrag, Fortschritt, Beiträge ein-/auszahlen.
class SavingsScreen extends ConsumerWidget {
  const SavingsScreen({super.key});

  Future<void> _editGoal(
    BuildContext context,
    WidgetRef ref, {
    SavingsGoal? goal,
  }) async {
    final l = AppLocalizations.of(context);
    final nameCtrl = TextEditingController(text: goal?.name ?? '');
    final targetCtrl = TextEditingController(
      text: (goal == null || goal.targetCents == 0)
          ? ''
          : centsToInput(goal.targetCents),
    );
    DateTime? date = goal?.targetDate;

    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: Text(goal == null ? l.newItem : l.edit),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                autofocus: true,
                decoration: InputDecoration(labelText: l.name),
              ),
              TextField(
                controller: targetCtrl,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: InputDecoration(
                  labelText: l.targetAmountHint,
                  prefixIcon: const Icon(Icons.euro),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      date == null
                          ? l.noTargetDate
                          : l.targetDateLabel(
                              DateFormat('dd.MM.yyyy').format(date!),
                            ),
                    ),
                  ),
                  TextButton(
                    onPressed: () async {
                      final picked = await showDatePicker(
                        context: ctx,
                        initialDate: date ?? DateTime.now(),
                        firstDate: DateTime(2000),
                        lastDate: DateTime(2100),
                      );
                      if (picked != null) setState(() => date = picked);
                    },
                    child: Text(l.dateLabel),
                  ),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(l.cancel),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(l.save),
            ),
          ],
        ),
      ),
    );
    if (saved == true) {
      final target = parseToCents(targetCtrl.text) ?? 0; // 0 = offener Topf
      if (nameCtrl.text.trim().isEmpty) return;
      await ref
          .read(savingsGoalRepositoryProvider)
          .upsertGoal(
            id: goal?.id,
            name: nameCtrl.text.trim(),
            targetCents: target < 0 ? 0 : target,
            targetDate: target > 0 ? date : null,
          );
    }
  }

  Future<void> _contribute(
    BuildContext context,
    WidgetRef ref,
    SavingsGoal g, {
    required bool deposit,
  }) async {
    final l = AppLocalizations.of(context);
    final ctrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(deposit ? l.deposit : l.withdraw),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(
            labelText: l.amount,
            prefixIcon: const Icon(Icons.euro),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('OK'),
          ),
        ],
      ),
    );
    if (ok == true) {
      final cents = parseToCents(ctrl.text) ?? 0;
      if (cents <= 0) return;
      await ref
          .read(savingsGoalRepositoryProvider)
          .addContribution(g.id, g.savedCents, deposit ? cents : -cents);
    }
  }

  /// Rundungs-Sparen: Summe der Aufrundungsdifferenzen (auf den nächsten Euro)
  /// aller Ausgaben dieses Monats in einen gewählten Topf/ein Sparziel einzahlen.
  Future<void> _roundupSweep(BuildContext context, WidgetRef ref) async {
    final l = AppLocalizations.of(context);
    final txs =
        ref.read(allTransactionsProvider).value ?? const <AppTransaction>[];
    final now = DateTime.now();
    var roundup = 0;
    for (final t in txs) {
      if (t.type != TransactionType.expense) continue;
      if (t.occurredOn.year != now.year || t.occurredOn.month != now.month) {
        continue;
      }
      roundup += (100 - t.amountCents % 100) % 100;
    }
    final goals = ref.read(savingsGoalsProvider).value ?? const [];
    if (roundup == 0) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l.noRoundupThisMonth)));
      return;
    }
    if (goals.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l.createGoalFirst)));
      return;
    }
    var chosen = goals.first.id;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: Text(l.roundupSaving),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(l.roundupThisMonth(formatCents(roundup))),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: chosen,
                decoration: InputDecoration(labelText: l.depositInto),
                items: [
                  for (final g in goals)
                    DropdownMenuItem(value: g.id, child: Text(g.name)),
                ],
                onChanged: (v) => setState(() => chosen = v ?? chosen),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(l.cancel),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(l.deposit),
            ),
          ],
        ),
      ),
    );
    if (ok == true) {
      final g = goals.firstWhere((e) => e.id == chosen);
      await ref
          .read(savingsGoalRepositoryProvider)
          .addContribution(g.id, g.savedCents, roundup);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l.depositedInto(formatCents(roundup), g.name)),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final goalsAsync = ref.watch(savingsGoalsProvider);
    return Scaffold(
      appBar: AppBar(
        title: Text(l.moreGoals),
        actions: [
          IconButton(
            tooltip: l.roundupSaving,
            icon: const Icon(Icons.savings_outlined),
            onPressed: () => _roundupSweep(context, ref),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _editGoal(context, ref),
        icon: const Icon(Icons.add),
        label: Text(l.newItem),
      ),
      body: goalsAsync.when(
        skipLoadingOnReload: true,
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text(l.errorWith(e))),
        data: (goals) {
          if (goals.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(l.noGoals),
              ),
            );
          }
          return ListView(
            padding: BentoListView.paddingOf(context, fabSpace: true),
            children: [
              // Schmal untereinander, breit zwei Ziele nebeneinander.
              BentoGrid(
                cells: [
                  for (final g in goals)
                    BentoCell(
                      span: 2,
                      wideSpan: 2,
                      child: _GoalTile(
                        goal: g,
                        onDeposit: () =>
                            _contribute(context, ref, g, deposit: true),
                        onWithdraw: () =>
                            _contribute(context, ref, g, deposit: false),
                        onEdit: () => _editGoal(context, ref, goal: g),
                        onDelete: () => ref
                            .read(savingsGoalRepositoryProvider)
                            .deleteGoal(g.id),
                      ),
                    ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Ein Sparziel als Kachel: gesparter Betrag groß, Ziel und Balken darunter,
/// Einzahlen unten. Offene Töpfe (ohne Zielbetrag) ohne Balken.
class _GoalTile extends StatelessWidget {
  const _GoalTile({
    required this.goal,
    required this.onDeposit,
    required this.onWithdraw,
    required this.onEdit,
    required this.onDelete,
  });

  final SavingsGoal goal;
  final VoidCallback onDeposit;
  final VoidCallback onWithdraw;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final t = Theme.of(context);
    final c = AppColors.of(context);
    final isPot = goal.targetCents <= 0;
    final pct = (goal.fraction * 100).round();
    final color = goal.reached ? c.income : t.colorScheme.primary;

    String? hint;
    if (!isPot && !goal.reached && goal.targetDate != null) {
      final now = DateTime.now();
      final monthsLeft =
          ((goal.targetDate!.year - now.year) * 12 +
                  (goal.targetDate!.month - now.month))
              .clamp(1, 1200);
      final perMonth = goal.remainingCents ~/ monthsLeft;
      hint =
          '${DateFormat('dd.MM.yyyy').format(goal.targetDate!)}'
          ' · ${l.perMonthNeeded(formatCents(perMonth))}';
    }

    return BentoTile(
      padding: const EdgeInsets.fromLTRB(18, 6, 6, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  goal.name,
                  style: t.textTheme.bodyLarge!.copyWith(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_horiz),
                onSelected: (v) {
                  switch (v) {
                    case 'edit':
                      onEdit();
                    case 'withdraw':
                      onWithdraw();
                    case 'delete':
                      onDelete();
                  }
                },
                itemBuilder: (ctx) => [
                  PopupMenuItem(value: 'edit', child: Text(l.edit)),
                  PopupMenuItem(value: 'withdraw', child: Text(l.withdraw)),
                  PopupMenuItem(value: 'delete', child: Text(l.delete)),
                ],
              ),
            ],
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: MoneyText(
                            goal.savedCents,
                            style: Bento.number(context, size: 28),
                          ),
                        ),
                      ),
                      if (!isPot) ...[
                        const SizedBox(width: 12),
                        Text(
                          '$pct %',
                          style: Bento.number(
                            context,
                            size: 17,
                          ).copyWith(color: color),
                        ),
                      ],
                    ],
                  ),
                  if (isPot)
                    Text(l.openPot, style: Bento.sub(context))
                  else ...[
                    MoneyText(
                      goal.targetCents,
                      prefix: l.ofWithSpace,
                      style: Bento.sub(context),
                    ),
                    const SizedBox(height: 12),
                    BentoProgress(
                      value: goal.fraction,
                      color: color,
                      height: 10,
                    ),
                    const SizedBox(height: 10),
                    if (goal.reached)
                      Text(
                        l.goalReached,
                        style: Bento.sub(context).copyWith(
                          color: c.income,
                          fontWeight: FontWeight.w600,
                        ),
                      )
                    else if (hint != null)
                      Text(hint, style: Bento.sub(context)),
                  ],
                  // Knopf unten, auch wenn die Nachbarkachel höher ist.
                  const Spacer(),
                  if (!goal.reached)
                    Padding(
                      padding: const EdgeInsets.only(top: 14),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: FilledButton.tonalIcon(
                          onPressed: onDeposit,
                          icon: const Icon(Icons.add),
                          label: Text(l.deposit),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
