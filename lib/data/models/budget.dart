/// Budget-Periode: Monat oder Woche.
enum BudgetPeriod { month, week }

BudgetPeriod budgetPeriodFromDb(String? s) =>
    s == 'week' ? BudgetPeriod.week : BudgetPeriod.month;

String budgetPeriodToDb(BudgetPeriod p) =>
    p == BudgetPeriod.week ? 'week' : 'month';

/// Budget, siehe Tabelle `budgets`. `categoryId == null` = Gesamtbudget über
/// alle Kategorien hinweg; sonst ein Budget für genau diese Kategorie.
class Budget {
  const Budget({
    required this.id,
    required this.categoryId,
    required this.amountCents,
    this.period = BudgetPeriod.month,
  });

  final String id;
  final String? categoryId;
  final int amountCents;
  final BudgetPeriod period;

  bool get isOverall => categoryId == null;

  factory Budget.fromJson(Map<String, dynamic> json) => Budget(
    id: json['id'] as String,
    categoryId: json['category_id'] as String?,
    amountCents: (json['amount_cents'] as num?)?.toInt() ?? 0,
    period: budgetPeriodFromDb(json['period'] as String?),
  );
}
