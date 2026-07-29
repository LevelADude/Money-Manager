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
    this.emoji,
    this.ownerId,
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

  /// 1–3 Emojis als alternatives Symbol (`null`/leer = Icon-Token nutzen).
  final String? emoji;

  /// Besitzer der Kategorie (`null` bei globalen Preset-Kategorien).
  final String? ownerId;
  final int sortOrder;

  /// Passt diese Kategorie zur gegebenen Buchungsrichtung?
  bool matches(TransactionType type) =>
      (kind == CategoryKind.income) == (type == TransactionType.income);

  Category copyWith({bool? active, int? sortOrder}) => Category(
    id: id,
    name: name,
    kind: kind,
    parentId: parentId,
    icon: icon,
    color: color,
    isPreset: isPreset,
    active: active ?? this.active,
    emoji: emoji,
    ownerId: ownerId,
    sortOrder: sortOrder ?? this.sortOrder,
  );

  factory Category.fromJson(Map<String, dynamic> json) => Category(
    id: json['id'] as String,
    name: json['name'] as String,
    kind: categoryKindFromDb((json['kind'] as String?) ?? 'expense'),
    parentId: json['parent_id'] as String?,
    icon: json['icon'] as String?,
    color: (json['color'] as num?)?.toInt(),
    isPreset: (json['is_preset'] as bool?) ?? false,
    active: (json['active'] as bool?) ?? true,
    emoji: json['emoji'] as String?,
    ownerId: json['owner_id'] as String?,
    sortOrder: (json['sort_order'] as num?)?.toInt() ?? 0,
  );
}
