/// Ein Sparziel: Zielbetrag, optionales Zieldatum, bisher gespart. Cent.
class SavingsGoal {
  const SavingsGoal({
    required this.id,
    required this.name,
    required this.targetCents,
    required this.savedCents,
    required this.targetDate,
  });

  final String id;
  final String name;
  final int targetCents;
  final int savedCents;
  final DateTime? targetDate;

  int get remainingCents => (targetCents - savedCents).clamp(0, targetCents);
  double get fraction =>
      targetCents <= 0 ? 0 : (savedCents / targetCents).clamp(0.0, 1.0);
  bool get reached => targetCents > 0 && savedCents >= targetCents;

  factory SavingsGoal.fromJson(Map<String, dynamic> json) => SavingsGoal(
    id: json['id'] as String,
    name: (json['name'] as String?) ?? '',
    targetCents: (json['target_cents'] as num?)?.toInt() ?? 0,
    savedCents: (json['saved_cents'] as num?)?.toInt() ?? 0,
    targetDate: json['target_date'] == null
        ? null
        : DateTime.parse(json['target_date'] as String),
  );
}
