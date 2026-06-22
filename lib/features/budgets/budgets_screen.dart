import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/budget.dart';
import '../../data/models/category.dart';
import '../../l10n/app_localizations.dart';
import '../../shared/category_icons.dart';
import '../../shared/money.dart';
import '../categories/category_providers.dart';
import 'budget_providers.dart';

/// Monatsbudgets je Ausgabe-Kategorie verwalten + Fortschritt anzeigen.
class BudgetsScreen extends ConsumerWidget {
  const BudgetsScreen({super.key});

  Future<void> _edit(
    BuildContext context,
    WidgetRef ref,
    Category cat,
    int? currentCents,
  ) async {
    final l = AppLocalizations.of(context);
    final controller = TextEditingController(
      text: currentCents == null ? '' : centsToInput(currentCents),
    );
    final cents = await showDialog<int>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l.budgetDialogTitle(cat.name)),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(
            labelText: l.monthlyBudget,
            prefixIcon: const Icon(Icons.euro),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, parseToCents(controller.text)),
            child: Text(l.save),
          ),
        ],
      ),
    );
    if (cents != null && cents > 0) {
      await ref
          .read(budgetRepositoryProvider)
          .setBudget(categoryId: cat.id, amountCents: cents);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cats = (ref.watch(categoriesProvider).asData?.value ??
            const <Category>[])
        .where((c) => c.kind == CategoryKind.expense && c.active)
        .toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    final budgets = ref.watch(budgetsByCategoryProvider);
    final spent = ref.watch(monthlySpentByCategoryProvider);

    final totalBudget =
        budgets.values.fold<int>(0, (s, b) => s + b.amountCents);
    final totalSpent =
        budgets.keys.fold<int>(0, (s, id) => s + (spent[id] ?? 0));

    final now = DateTime.now();
    final daysInMonth = DateTime(now.year, now.month + 1, 0).day;
    final daysLeft = daysInMonth - now.day + 1;

    return Scaffold(
      appBar: AppBar(title: Text(AppLocalizations.of(context).moreBudgets)),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          _OverallBudgetCard(
            totalSpent: totalSpent,
            totalBudget: totalBudget,
            daysLeft: daysLeft,
          ),
          const SizedBox(height: 8),
          for (final cat in cats)
            _BudgetTile(
              category: cat,
              budget: budgets[cat.id],
              spentCents: spent[cat.id] ?? 0,
              onEdit: () => _edit(context, ref, cat, budgets[cat.id]?.amountCents),
              onRemove: budgets[cat.id] == null
                  ? null
                  : () => ref
                      .read(budgetRepositoryProvider)
                      .deleteBudget(budgets[cat.id]!.id),
            ),
        ],
      ),
    );
  }
}

class _OverallBudgetCard extends StatelessWidget {
  const _OverallBudgetCard({
    required this.totalSpent,
    required this.totalBudget,
    required this.daysLeft,
  });

  final int totalSpent;
  final int totalBudget;
  final int daysLeft;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final hasBudget = totalBudget > 0;
    final frac = hasBudget ? (totalSpent / totalBudget).clamp(0.0, 1.0) : 0.0;
    final pct = hasBudget ? (totalSpent / totalBudget * 100).round() : 0;
    final remaining = totalBudget - totalSpent;
    final over = remaining < 0;
    final color = over
        ? Colors.red.shade600
        : (pct >= 90 ? Colors.orange.shade700 : Colors.green.shade600);
    final perDay = (!over && daysLeft > 0) ? remaining ~/ daysLeft : 0;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(l.thisMonthWithBudget,
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                ),
                if (hasBudget)
                  Text('$pct %',
                      style: TextStyle(
                          fontWeight: FontWeight.bold, color: color)),
              ],
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(5),
              child: LinearProgressIndicator(
                value: frac,
                minHeight: 10,
                color: color,
                backgroundColor: color.withValues(alpha: 0.15),
              ),
            ),
            const SizedBox(height: 8),
            Text(l.amountOf(formatCents(totalSpent), formatCents(totalBudget))),
            if (hasBudget)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  over
                      ? l.budgetExceededBy(formatCents(-remaining))
                      : l.budgetRemainingLine(formatCents(remaining), daysLeft,
                          formatCents(perDay)),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: over ? Colors.red.shade700 : null),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _BudgetTile extends StatelessWidget {
  const _BudgetTile({
    required this.category,
    required this.budget,
    required this.spentCents,
    required this.onEdit,
    required this.onRemove,
  });

  final Category category;
  final Budget? budget;
  final int spentCents;
  final VoidCallback onEdit;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final hasBudget = budget != null;
    final amount = budget?.amountCents ?? 0;
    final over = hasBudget && spentCents > amount;
    final frac = (hasBudget && amount > 0)
        ? (spentCents / amount).clamp(0.0, 1.0)
        : 0.0;
    final pct = (hasBudget && amount > 0)
        ? (spentCents / amount * 100).round()
        : 0;
    final color = over
        ? Colors.red.shade600
        : (pct >= 90 ? Colors.orange.shade700 : Colors.green.shade600);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(iconForToken(category.icon)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(category.name,
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                ),
                if (hasBudget) ...[
                  IconButton(
                    tooltip: l.edit,
                    icon: const Icon(Icons.edit_outlined),
                    onPressed: onEdit,
                  ),
                  IconButton(
                    tooltip: l.remove,
                    icon: const Icon(Icons.delete_outline),
                    onPressed: onRemove,
                  ),
                ] else
                  TextButton(
                    onPressed: onEdit,
                    child: Text(l.setBudgetAction),
                  ),
              ],
            ),
            if (hasBudget) ...[
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: frac,
                  minHeight: 8,
                  color: color,
                  backgroundColor: color.withValues(alpha: 0.15),
                ),
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                      '${l.amountOf(formatCents(spentCents), formatCents(amount))} · $pct %'),
                  Text(
                    over
                        ? l.overBy(formatCents(spentCents - amount))
                        : l.amountLeft(formatCents(amount - spentCents)),
                    style: TextStyle(
                      color: over
                          ? Colors.red.shade700
                          : (pct >= 90 ? Colors.orange.shade800 : null),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ] else
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  l.noBudgetThisMonth(formatCents(spentCents)),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
