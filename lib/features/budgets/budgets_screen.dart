import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/budget.dart';
import '../../data/models/category.dart';
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
    final controller = TextEditingController(
      text: currentCents == null ? '' : centsToInput(currentCents),
    );
    final cents = await showDialog<int>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Budget: ${cat.name}'),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(
            labelText: 'Monatsbudget',
            prefixIcon: Icon(Icons.euro),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Abbrechen'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, parseToCents(controller.text)),
            child: const Text('Speichern'),
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

    return Scaffold(
      appBar: AppBar(title: const Text('Budgets')),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          Card(
            child: ListTile(
              leading: const Icon(Icons.pie_chart_outline),
              title: const Text('Diesen Monat (mit Budget)'),
              subtitle: Text(
                  '${formatCents(totalSpent)} von ${formatCents(totalBudget)}'),
            ),
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
    final hasBudget = budget != null;
    final amount = budget?.amountCents ?? 0;
    final over = hasBudget && spentCents > amount;
    final frac = (hasBudget && amount > 0)
        ? (spentCents / amount).clamp(0.0, 1.0)
        : 0.0;
    final color = over ? Colors.red.shade600 : Colors.green.shade600;

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
                    tooltip: 'Bearbeiten',
                    icon: const Icon(Icons.edit_outlined),
                    onPressed: onEdit,
                  ),
                  IconButton(
                    tooltip: 'Entfernen',
                    icon: const Icon(Icons.delete_outline),
                    onPressed: onRemove,
                  ),
                ] else
                  TextButton(
                    onPressed: onEdit,
                    child: const Text('Budget setzen'),
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
                  Text('${formatCents(spentCents)} von ${formatCents(amount)}'),
                  if (over)
                    Text('überschritten',
                        style: TextStyle(
                            color: Colors.red.shade700,
                            fontWeight: FontWeight.bold)),
                ],
              ),
            ] else
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  'Kein Budget · diesen Monat ${formatCents(spentCents)}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
