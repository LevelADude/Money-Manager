import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart' hide TextDirection;

import '../../data/models/savings_goal.dart';
import '../../shared/money.dart';
import '../../shared/money_text.dart';
import 'savings_providers.dart';

/// Sparziele: Zielbetrag, Fortschritt, Beiträge ein-/auszahlen.
class SavingsScreen extends ConsumerWidget {
  const SavingsScreen({super.key});

  Future<void> _editGoal(BuildContext context, WidgetRef ref,
      {SavingsGoal? goal}) async {
    final nameCtrl = TextEditingController(text: goal?.name ?? '');
    final targetCtrl = TextEditingController(
        text: goal == null ? '' : centsToInput(goal.targetCents));
    DateTime? date = goal?.targetDate;

    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: Text(goal == null ? 'Neues Sparziel' : 'Sparziel bearbeiten'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                autofocus: true,
                decoration: const InputDecoration(labelText: 'Name'),
              ),
              TextField(
                controller: targetCtrl,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                    labelText: 'Zielbetrag', prefixIcon: Icon(Icons.euro)),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: Text(date == null
                        ? 'Kein Zieldatum'
                        : 'Ziel: ${DateFormat('dd.MM.yyyy').format(date!)}'),
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
                    child: const Text('Datum'),
                  ),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Abbrechen')),
            FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Speichern')),
          ],
        ),
      ),
    );
    if (saved == true) {
      final target = parseToCents(targetCtrl.text) ?? 0;
      if (nameCtrl.text.trim().isEmpty || target <= 0) return;
      await ref.read(savingsGoalRepositoryProvider).upsertGoal(
            id: goal?.id,
            name: nameCtrl.text.trim(),
            targetCents: target,
            targetDate: date,
          );
    }
  }

  Future<void> _contribute(BuildContext context, WidgetRef ref, SavingsGoal g,
      {required bool deposit}) async {
    final ctrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(deposit ? 'Einzahlen' : 'Abheben'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration:
              const InputDecoration(labelText: 'Betrag', prefixIcon: Icon(Icons.euro)),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Abbrechen')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('OK')),
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

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final goalsAsync = ref.watch(savingsGoalsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Sparziele')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _editGoal(context, ref),
        icon: const Icon(Icons.add),
        label: const Text('Sparziel'),
      ),
      body: goalsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Fehler: $e')),
        data: (goals) {
          if (goals.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text('Noch keine Sparziele. Lege unten eines an.'),
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
    final pct = (goal.fraction * 100).round();
    final color =
        goal.reached ? Colors.green.shade700 : Theme.of(context).colorScheme.primary;

    String? hint;
    if (!goal.reached && goal.targetDate != null) {
      final now = DateTime.now();
      final monthsLeft =
          ((goal.targetDate!.year - now.year) * 12 +
                  (goal.targetDate!.month - now.month))
              .clamp(1, 1200);
      final perMonth = goal.remainingCents ~/ monthsLeft;
      hint = '${DateFormat('dd.MM.yyyy').format(goal.targetDate!)}'
          ' · ${formatCents(perMonth)}/Monat nötig';
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
                  child: Text(goal.name,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 16)),
                ),
                Text('$pct %',
                    style: TextStyle(fontWeight: FontWeight.bold, color: color)),
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
                  itemBuilder: (ctx) => const [
                    PopupMenuItem(value: 'edit', child: Text('Bearbeiten')),
                    PopupMenuItem(value: 'withdraw', child: Text('Abheben')),
                    PopupMenuItem(value: 'delete', child: Text('Löschen')),
                  ],
                ),
              ],
            ),
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
                MoneyText(goal.savedCents,
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                MoneyText(goal.targetCents,
                    prefix: 'von ',
                    style: TextStyle(color: Theme.of(context).hintColor)),
              ],
            ),
            if (goal.reached)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text('Ziel erreicht! 🎉',
                    style: TextStyle(
                        color: Colors.green.shade700,
                        fontWeight: FontWeight.bold)),
              )
            else ...[
              if (hint != null)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(hint,
                      style: Theme.of(context).textTheme.bodySmall),
                ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerLeft,
                child: FilledButton.tonalIcon(
                  onPressed: onDeposit,
                  icon: const Icon(Icons.add),
                  label: const Text('Einzahlen'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
