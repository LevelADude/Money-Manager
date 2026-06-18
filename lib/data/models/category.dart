import 'app_transaction.dart' show TransactionType;

/// Art einer Kategorie – Einnahme oder Ausgabe (passend zum Buchungstyp).
enum CategoryKind { income, expense }

CategoryKind categoryKindFromDb(String s) =>
    s == 'income' ? CategoryKind.income : CategoryKind.expense;

String categoryKindToDb(CategoryKind k) =>
    k == CategoryKind.income ? 'income' : 'expense';

/// Eine gruppenweite Kategorie, siehe Tabelle `categories`.
class Category {
  const Category({
    required this.id,
    required this.name,
    required this.kind,
    required this.parentId,
    required this.icon,
    required this.color,
    required this.isPreset,
    required this.active,
    this.sortOrder = 0,
  });

  final String id;
  final String name;
  final CategoryKind kind;
  final String? parentId;
  final String? icon;
  final int? color;
  final bool isPreset;
  final bool active;
  final int sortOrder;

  /// Passt diese Kategorie zur gegebenen Buchungsrichtung?
  bool matches(TransactionType type) =>
      (kind == CategoryKind.income) == (type == TransactionType.income);

  factory Category.fromJson(Map<String, dynamic> json) => Category(
        id: json['id'] as String,
        name: json['name'] as String,
        kind: categoryKindFromDb((json['kind'] as String?) ?? 'expense'),
        parentId: json['parent_id'] as String?,
        icon: json['icon'] as String?,
        color: (json['color'] as num?)?.toInt(),
        isPreset: (json['is_preset'] as bool?) ?? false,
        active: (json['active'] as bool?) ?? true,
        sortOrder: (json['sort_order'] as num?)?.toInt() ?? 0,
      );
}
