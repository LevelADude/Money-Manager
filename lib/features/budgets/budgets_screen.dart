import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/budget.dart';
import '../../data/models/category.dart';
import '../../l10n/app_localizations.dart';
import '../../shared/category_icons.dart';
import '../../shared/money.dart';
import '../categories/category_providers.dart';
import 'budget_providers.dart';
import '../../core/theme.dart';
import '../../shared/bento.dart';

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
  Future<void> _run(
    BuildContext context,
    Future<void> Function() action,
  ) async {
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

    // Kategorien mit Budget zuerst (mit Balken), die übrigen darunter in
    // einer eigenen Kachel – beide Gruppen alphabetisch.
    final withBudget = [
      for (final c in cats)
        if (budgets[c.id] != null) c,
    ];
    final withoutBudget = [
      for (final c in cats)
        if (budgets[c.id] == null) c,
    ];
    void remove(String id) =>
        ref.read(budgetRepositoryProvider).deleteBudget(id);

    return Scaffold(
      appBar: AppBar(title: Text(AppLocalizations.of(context).moreBudgets)),
      body: ListView(
        padding: BentoListView.paddingOf(context),
        children: [
          BentoGrid(
            cells: [
              BentoCell(
                span: 2,
                wideSpan: overall == null ? 4 : 2,
                child: _OverallBudgetTile(
                  budget: overall,
                  spent: overallSpent,
                  period: period,
                  daysLeft: daysLeft,
                  onEdit: () => _editOverall(context, ref, overall),
                  onRemove: overall == null ? null : () => remove(overall.id),
                ),
              ),
              if (overall != null)
                BentoCell(
                  span: 2,
                  wideSpan: 2,
                  child: _AllocationTile(
                    overallCents: overall.amountCents,
                    allocatedCents: allocated,
                  ),
                ),
            ],
          ),
          if (withBudget.isNotEmpty) ...[
            const SizedBox(height: Bento.gap),
            BentoList(
              children: [
                for (final cat in withBudget)
                  _BudgetRow(
                    category: cat,
                    budget: budgets[cat.id]!,
                    spentCents: spent[cat.id] ?? 0,
                    onEdit: () =>
                        _edit(context, ref, cat, budgets[cat.id]!.amountCents),
                    onRemove: () => remove(budgets[cat.id]!.id),
                  ),
              ],
            ),
          ],
          if (withoutBudget.isNotEmpty) ...[
            const SizedBox(height: Bento.gap),
            BentoList(
              children: [
                for (final cat in withoutBudget)
                  _OpenBudgetRow(
                    category: cat,
                    period: period,
                    spentCents: spent[cat.id] ?? 0,
                    onEdit: () => _edit(context, ref, cat, null),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// Signalfarbe eines Budgets: überzogen rot, ab 90 % Warnung, sonst grün.
Color _budgetColor(
  BuildContext context, {
  required bool over,
  required int pct,
}) {
  final c = AppColors.of(context);
  return over ? c.expense : (pct >= 90 ? c.warning : c.income);
}

/// Kleiner Bearbeiten-/Entfernen-Knopf in Kopf- und Listenzeilen.
class _TileAction extends StatelessWidget {
  const _TileAction({
    required this.tooltip,
    required this.icon,
    required this.onPressed,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => IconButton(
    tooltip: tooltip,
    icon: Icon(icon, size: 20),
    visualDensity: VisualDensity.compact,
    onPressed: onPressed,
  );
}

/// Gesamtbudget: Ausgaben im Zeitraum gegen das Budget, Balken und was pro
/// Tag noch bleibt. Ohne Budget: bisherige Ausgaben, Erklärung, Knopf.
class _OverallBudgetTile extends StatelessWidget {
  const _OverallBudgetTile({
    required this.budget,
    required this.spent,
    required this.period,
    required this.daysLeft,
    required this.onEdit,
    required this.onRemove,
  });

  final Budget? budget;
  final int spent;
  final BudgetPeriod period;
  final int daysLeft;
  final VoidCallback onEdit;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final budget = this.budget;
    final periodLabel = period == BudgetPeriod.week ? l.thisWeek : l.thisMonth;

    if (budget == null) {
      return BentoTile(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(l.overallBudget, style: Bento.label(context)),
            const SizedBox(height: 6),
            Text(
              l.overallBudgetHint,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 4),
            Text(
              '$periodLabel: ${formatCents(spent)}',
              style: Bento.sub(context),
            ),
            const SizedBox(height: 14),
            FilledButton.tonal(
              onPressed: onEdit,
              child: Text(l.setOverallBudget),
            ),
          ],
        ),
      );
    }

    final amount = budget.amountCents;
    final pct = amount > 0 ? (spent / amount * 100).round() : 0;
    final remaining = amount - spent;
    final over = remaining < 0;
    final color = _budgetColor(context, over: over, pct: pct);
    final perDay = (!over && daysLeft > 0) ? remaining ~/ daysLeft : 0;

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
                  '${l.overallBudget} · $periodLabel',
                  style: Bento.label(context),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              _TileAction(
                tooltip: l.edit,
                icon: Icons.edit_outlined,
                onPressed: onEdit,
              ),
              _TileAction(
                tooltip: l.remove,
                icon: Icons.delete_outline,
                onPressed: onRemove,
              ),
            ],
          ),
          Padding(
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
                        child: Text(
                          l.amountOf(formatCents(spent), formatCents(amount)),
                          style: Bento.number(context, size: 24),
                          // Einzeilig messen, sonst wird die Kachel im Raster
                          // so hoch wie ein umbrochener Betrag.
                          maxLines: 1,
                          softWrap: false,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      '$pct %',
                      style: Bento.number(
                        context,
                        size: 17,
                      ).copyWith(color: color),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                BentoProgress(
                  value: amount > 0 ? spent / amount : 0,
                  color: color,
                  height: 10,
                ),
                const SizedBox(height: 10),
                Text(
                  over
                      ? l.budgetExceededBy(formatCents(-remaining))
                      : l.budgetRemainingLine(
                          formatCents(remaining),
                          daysLeft,
                          formatCents(perDay),
                        ),
                  style: Bento.sub(context).copyWith(
                    color: over ? AppColors.of(context).expense : null,
                    fontWeight: over ? FontWeight.w600 : null,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Zeigt, wie viel des Gesamtbudgets schon auf Kategorie-Budgets verteilt ist
/// und wie viel noch frei verplant werden kann.
class _AllocationTile extends StatelessWidget {
  const _AllocationTile({
    required this.overallCents,
    required this.allocatedCents,
  });

  final int overallCents;
  final int allocatedCents;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final free = overallCents - allocatedCents;
    final overAllocated = free < 0;
    final color = overAllocated ? AppColors.of(context).expense : null;

    return BentoTile(
      padding: const EdgeInsets.fromLTRB(18, 6, 18, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          // So hoch wie die Kopfzeile der Gesamtbudget-Kachel (mit Knöpfen),
          // damit Zahl und Balken beider Kacheln auf einer Linie liegen.
          SizedBox(
            height: 40,
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(l.budgetAllocationTitle, style: Bento.label(context)),
            ),
          ),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              formatCents(allocatedCents),
              style: Bento.number(context, size: 24),
            ),
          ),
          const SizedBox(height: 12),
          BentoProgress(
            value: overallCents > 0 ? allocatedCents / overallCents : 0,
            color: color,
            height: 10,
          ),
          const SizedBox(height: 10),
          Text(
            overAllocated
                ? l.budgetOverAllocatedBy(formatCents(-free))
                : l.budgetFreeToAllocate(formatCents(free)),
            style: Bento.sub(context).copyWith(
              color: color,
              fontWeight: overAllocated ? FontWeight.w600 : null,
            ),
          ),
          Text(
            l.budgetAllocatedOf(
              formatCents(allocatedCents),
              formatCents(overallCents),
            ),
            style: Bento.sub(context),
          ),
        ],
      ),
    );
  }
}

/// Kategorie mit Budget: Kreis, Name, Stand und Rest; Balken darunter.
/// Antippen bearbeitet das Budget.
class _BudgetRow extends StatelessWidget {
  const _BudgetRow({
    required this.category,
    required this.budget,
    required this.spentCents,
    required this.onEdit,
    required this.onRemove,
  });

  final Category category;
  final Budget budget;
  final int spentCents;
  final VoidCallback onEdit;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final amount = budget.amountCents;
    final over = spentCents > amount;
    final pct = amount > 0 ? (spentCents / amount * 100).round() : 0;
    final color = _budgetColor(context, over: over, pct: pct);
    final warn = over || pct >= 90;

    return InkWell(
      onTap: onEdit,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          BentoRow(
            padding: const EdgeInsets.fromLTRB(14, 8, 6, 2),
            leading: BentoGlyph(
              size: 38,
              child: categoryGlyph(category, size: 22),
            ),
            title: Text(l.categoryName(category)),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '$pct %',
                  style: Bento.sub(context).copyWith(
                    fontWeight: FontWeight.w600,
                    color: warn ? color : null,
                  ),
                ),
                _TileAction(
                  tooltip: l.remove,
                  icon: Icons.delete_outline,
                  onPressed: onRemove,
                ),
              ],
            ),
          ),
          // Balken und Zahlen bündig mit dem Namen, nicht mit dem Kreis; so
          // bleibt der Zeile die volle Breite für Stand und Rest.
          Padding(
            padding: const EdgeInsets.fromLTRB(64, 0, 18, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                BentoProgress(
                  value: amount > 0 ? spentCents / amount : 0,
                  color: color,
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        l.amountOf(
                          formatCents(spentCents),
                          formatCents(amount),
                        ),
                        style: Bento.sub(context),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      over
                          ? l.overBy(formatCents(spentCents - amount))
                          : l.amountLeft(formatCents(amount - spentCents)),
                      style: Bento.sub(context).copyWith(
                        fontWeight: FontWeight.w600,
                        color: warn ? color : null,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Kategorie ohne Budget: Ausgaben im Zeitraum und Knopf zum Festlegen.
class _OpenBudgetRow extends StatelessWidget {
  const _OpenBudgetRow({
    required this.category,
    required this.period,
    required this.spentCents,
    required this.onEdit,
  });

  final Category category;
  final BudgetPeriod period;
  final int spentCents;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return BentoRow(
      onTap: onEdit,
      padding: const EdgeInsets.fromLTRB(14, 10, 4, 10),
      leading: BentoGlyph(size: 38, child: categoryGlyph(category, size: 22)),
      title: Text(l.categoryName(category)),
      // Dass kein Budget gesetzt ist, sagt schon der Knopf; die Zeile zeigt
      // nur, was im Zeitraum ausgegeben wurde (passt so auch aufs Telefon).
      subtitle: Text(
        '${period == BudgetPeriod.week ? l.thisWeek : l.thisMonth}: '
        '${formatCents(spentCents)}',
      ),
      trailing: TextButton(
        style: TextButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          visualDensity: VisualDensity.compact,
        ),
        onPressed: onEdit,
        child: Text(l.setBudgetAction),
      ),
    );
  }
}
