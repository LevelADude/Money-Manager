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
    final period = ref.read(budgetPeriodProvider);
    final overall = ref.read(overallBudgetProvider);
    // Was ohne DIESE Kategorie bereits verplant ist – dagegen wird geprüft.
    final allocatedOthers =
        ref.read(allocatedBudgetCentsProvider) - (currentCents ?? 0);
    final freeForThis = overall == null
        ? null
        : overall.amountCents - allocatedOthers;
    final controller = TextEditingController(
      text: currentCents == null ? '' : centsToInput(currentCents),
    );
    final cents = await showDialog<int>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l.budgetDialogTitle(l.categoryName(cat))),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(
            labelText: period == BudgetPeriod.week
                ? l.weeklyBudget
                : l.monthlyBudget,
            prefixIcon: const Icon(Icons.euro),
            helperText: freeForThis == null
                ? null
                : l.budgetFreeToAllocate(formatCents(freeForThis)),
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
    if (cents == null || cents <= 0) return;

    // Warnung, wenn die Summe der Kategorie-Budgets das Gesamtbudget sprengt.
    final check = checkAllocation(
      overallCents: overall?.amountCents,
      allocatedOtherCents: allocatedOthers,
      newCents: cents,
    );
    if (check.exceeds) {
      if (!context.mounted) return;
      final ok = await _confirmOverAllocation(
        context,
        l.budgetExceedsOverallBody(
          formatCents(check.planned),
          formatCents(overall!.amountCents),
          formatCents(check.overBy),
        ),
      );
      if (ok != true) return;
    }

    if (!context.mounted) return;
    await _run(
      context,
      () => ref
          .read(budgetRepositoryProvider)
          .setCategoryBudget(
            categoryId: cat.id,
            amountCents: cents,
            period: period,
            existingId: ref.read(budgetsByCategoryProvider)[cat.id]?.id,
          ),
    );
  }

  /// Rückfrage bei Überschreitung – Speichern bleibt bewusst möglich.
  Future<bool?> _confirmOverAllocation(BuildContext context, String body) {
    final l = AppLocalizations.of(context);
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: const Icon(Icons.warning_amber_rounded),
        title: Text(l.budgetExceedsOverallTitle),
        content: Text(body),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l.saveAnyway),
          ),
        ],
      ),
    );
  }

  /// Schreibt und zeigt Fehler an, statt sie stumm zu verschlucken.
  Future<void> _run(BuildContext context, Future<void> Function() action) async {
    final messenger = ScaffoldMessenger.of(context);
    final l = AppLocalizations.of(context);
    try {
      await action();
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('${l.budgetSaveFailed}: $e')),
      );
    }
  }

  /// Gesamtbudget (kategorieunabhängig) festlegen – Betrag + Zeitraum.
  Future<void> _editOverall(
    BuildContext context,
    WidgetRef ref,
    Budget? existing,
  ) async {
    final l = AppLocalizations.of(context);
    final ctrl = TextEditingController(
      text: existing == null ? '' : centsToInput(existing.amountCents),
    );
    var period = existing?.period ?? BudgetPeriod.month;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: Text(l.overallBudget),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SegmentedButton<BudgetPeriod>(
                segments: [
                  ButtonSegment(
                    value: BudgetPeriod.month,
                    label: Text(l.periodMonth),
                  ),
                  ButtonSegment(
                    value: BudgetPeriod.week,
                    label: Text(l.periodWeek),
                  ),
                ],
                selected: {period},
                onSelectionChanged: (s) => setState(() => period = s.first),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: ctrl,
                autofocus: true,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: InputDecoration(
                  labelText: l.overallBudget,
                  prefixIcon: const Icon(Icons.euro),
                  helperText: l.budgetPeriodAppliesToAll,
                  helperMaxLines: 2,
                ),
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
    if (ok != true) return;
    final cents = parseToCents(ctrl.text);
    if (cents == null || cents <= 0) return;

    // Hinweis, wenn das neue Gesamtbudget unter dem liegt, was bereits auf
    // Kategorien verteilt ist – speichern bleibt möglich.
    final allocated = ref.read(allocatedBudgetCentsProvider);
    if (allocated > cents) {
      if (!context.mounted) return;
      final go = await _confirmOverAllocation(
        context,
        l.budgetBelowAllocatedBody(
          formatCents(allocated),
          formatCents(allocated - cents),
        ),
      );
      if (go != true) return;
    }

    if (!context.mounted) return;
    final periodChanged = existing != null && existing.period != period;
    await _run(context, () async {
      await ref
          .read(budgetRepositoryProvider)
          .setOverallBudget(
            period: period,
            amountCents: cents,
            existingId: existing?.id,
          );
      // Kategorie-Budgets ziehen mit, damit Teil- und Gesamtbudget denselben
      // Zeitraum meinen (sonst wäre die Aufteilung nicht vergleichbar).
      if (periodChanged || existing == null) {
        await ref
            .read(budgetRepositoryProvider)
            .setPeriodForAllCategoryBudgets(period);
      }
    });
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cats =
        (ref.watch(categoriesProvider).value ?? const <Category>[])
            .where((c) => c.kind == CategoryKind.expense && c.active)
            .toList()
          ..sort(
            (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
          );
    final budgets = ref.watch(budgetsByCategoryProvider);

    // Eigenständiges Gesamtbudget (kategorieunabhängig, Monat/Woche). Sein
    // Zeitraum gilt für alle Budgets – auch für die Ausgaben-Fenster.
    final overall = ref.watch(overallBudgetProvider);
    final period = ref.watch(budgetPeriodProvider);
    final spent = ref.watch(spentByCategoryProvider(period));
    final overallSpent = ref.watch(periodExpenseTotalProvider(period));
    final allocated = ref.watch(allocatedBudgetCentsProvider);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final (_, periodEnd) = budgetPeriodWindow(period, now);
    final daysLeft = periodEnd.difference(today).inDays;

    return Scaffold(
      appBar: AppBar(title: Text(AppLocalizations.of(context).moreBudgets)),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          _OverallBudgetCard(
            budget: overall,
            spent: overallSpent,
            allocated: allocated,
            period: period,
            daysLeft: daysLeft,
            onEdit: () => _editOverall(context, ref, overall),
            onRemove: overall == null
                ? null
                : () => ref
                      .read(budgetRepositoryProvider)
                      .deleteBudget(overall.id),
          ),
          const SizedBox(height: 8),
          for (final cat in cats)
            _BudgetTile(
              category: cat,
              budget: budgets[cat.id],
              period: period,
              spentCents: spent[cat.id] ?? 0,
              onEdit: () =>
                  _edit(context, ref, cat, budgets[cat.id]?.amountCents),
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
    required this.budget,
    required this.spent,
    required this.allocated,
    required this.period,
    required this.daysLeft,
    required this.onEdit,
    required this.onRemove,
  });

  final Budget? budget;
  final int spent;

  /// Summe der auf Kategorien verteilten Budgets.
  final int allocated;
  final BudgetPeriod period;
  final int daysLeft;
  final VoidCallback onEdit;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final hasBudget = budget != null;
    final amount = budget?.amountCents ?? 0;
    final frac = (hasBudget && amount > 0)
        ? (spent / amount).clamp(0.0, 1.0)
        : 0.0;
    final pct = (hasBudget && amount > 0) ? (spent / amount * 100).round() : 0;
    final remaining = amount - spent;
    final over = hasBudget && remaining < 0;
    final color = over
        ? Colors.red.shade600
        : (pct >= 90 ? Colors.orange.shade700 : Colors.green.shade600);
    final perDay = (!over && daysLeft > 0) ? remaining ~/ daysLeft : 0;
    final periodLabel = period == BudgetPeriod.week ? l.thisWeek : l.thisMonth;

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
                    hasBudget
                        ? '${l.overallBudget} · $periodLabel'
                        : l.overallBudget,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                if (hasBudget) ...[
                  Text(
                    '$pct %',
                    style: TextStyle(fontWeight: FontWeight.bold, color: color),
                  ),
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
                ],
              ],
            ),
            if (hasBudget) ...[
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
              Text(l.amountOf(formatCents(spent), formatCents(amount))),
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  over
                      ? l.budgetExceededBy(formatCents(-remaining))
                      : l.budgetRemainingLine(
                          formatCents(remaining),
                          daysLeft,
                          formatCents(perDay),
                        ),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: over ? Colors.red.shade700 : null,
                  ),
                ),
              ),
              const Divider(height: 24),
              _AllocationBlock(overallCents: amount, allocatedCents: allocated),
            ] else ...[
              const SizedBox(height: 6),
              Text(
                l.overallBudgetHint,
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: Text('${l.thisMonth}: ${formatCents(spent)}'),
                  ),
                  FilledButton.tonal(
                    onPressed: onEdit,
                    child: Text(l.setOverallBudget),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Zeigt, wie viel des Gesamtbudgets schon auf Kategorie-Budgets verteilt ist
/// und wie viel noch frei verplant werden kann.
class _AllocationBlock extends StatelessWidget {
  const _AllocationBlock({
    required this.overallCents,
    required this.allocatedCents,
  });

  final int overallCents;
  final int allocatedCents;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final free = overallCents - allocatedCents;
    final overAllocated = free < 0;
    final frac = overallCents > 0
        ? (allocatedCents / overallCents).clamp(0.0, 1.0)
        : 0.0;
    final color = overAllocated
        ? Colors.red.shade600
        : theme.colorScheme.primary;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                l.budgetAllocationTitle,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            Text(
              l.budgetAllocatedOf(
                formatCents(allocatedCents),
                formatCents(overallCents),
              ),
              style: theme.textTheme.bodySmall,
            ),
          ],
        ),
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
        Text(
          overAllocated
              ? l.budgetOverAllocatedBy(formatCents(-free))
              : l.budgetFreeToAllocate(formatCents(free)),
          style: theme.textTheme.bodySmall?.copyWith(
            color: overAllocated ? Colors.red.shade700 : null,
            fontWeight: overAllocated ? FontWeight.bold : null,
          ),
        ),
      ],
    );
  }
}

class _BudgetTile extends StatelessWidget {
  const _BudgetTile({
    required this.category,
    required this.budget,
    required this.period,
    required this.spentCents,
    required this.onEdit,
    required this.onRemove,
  });

  final Category category;
  final Budget? budget;
  final BudgetPeriod period;
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
                  child: Text(
                    l.categoryName(category),
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
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
                  TextButton(onPressed: onEdit, child: Text(l.setBudgetAction)),
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
                    '${l.amountOf(formatCents(spentCents), formatCents(amount))} · $pct %',
                  ),
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
                  period == BudgetPeriod.week
                      ? l.noBudgetThisWeek(formatCents(spentCents))
                      : l.noBudgetThisMonth(formatCents(spentCents)),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
