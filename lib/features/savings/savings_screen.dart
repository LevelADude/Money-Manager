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
        ref.read(allTransactionsProvider).asData?.value ??
        const <AppTransaction>[];
    final now = DateTime.now();
    var roundup = 0;
    for (final t in txs) {
      if (t.type != TransactionType.expense) continue;
      if (t.occurredOn.year != now.year || t.occurredOn.month != now.month) {
        continue;
      }
      roundup += (100 - t.amountCents % 100) % 100;
    }
    final goals = ref.read(savingsGoalsProvider).asData?.value ?? const [];
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
            padding: const EdgeInsets.all(12),
            children: [
              for (final g in goals)
                _GoalCard(
                  goal: g,
                  onDeposit: () => _contribute(context, ref, g, deposit: true),
                  onWithdraw: () =>
                      _contribute(context, ref, g, deposit: false),
                  onEdit: () => _editGoal(context, ref, goal: g),
                  onDelete: () =>
                      ref.read(savingsGoalRepositoryProvider).deleteGoal(g.id),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _GoalCard extends StatelessWidget {
  const _GoalCard({
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
    final isPot = goal.targetCents <= 0;
    final pct = (goal.fraction * 100).round();
    final color = goal.reached
        ? Colors.green.shade700
        : Theme.of(context).colorScheme.primary;

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

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    goal.name,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
                if (!isPot)
                  Text(
                    '$pct %',
                    style: TextStyle(fontWeight: FontWeight.bold, color: color),
                  ),
                PopupMenuButton<String>(
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
            if (isPot) ...[
              const SizedBox(height: 6),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(l.openPot, style: Theme.of(context).textTheme.bodySmall),
                  MoneyText(
                    goal.savedCents,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerLeft,
                child: FilledButton.tonalIcon(
                  onPressed: onDeposit,
                  icon: const Icon(Icons.add),
                  label: Text(l.deposit),
                ),
              ),
            ] else ...[
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(5),
                child: LinearProgressIndicator(
                  value: goal.fraction,
                  minHeight: 10,
                  color: color,
                  backgroundColor: color.withValues(alpha: 0.15),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  MoneyText(
                    goal.savedCents,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  MoneyText(
                    goal.targetCents,
                    prefix: l.ofWithSpace,
                    style: TextStyle(color: Theme.of(context).hintColor),
                  ),
                ],
              ),
              if (goal.reached)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    l.goalReached,
                    style: TextStyle(
                      color: Colors.green.shade700,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                )
              else ...[
                if (hint != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      hint,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerLeft,
                  child: FilledButton.tonalIcon(
                    onPressed: onDeposit,
                    icon: const Icon(Icons.add),
                    label: Text(l.deposit),
                  ),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }
}
