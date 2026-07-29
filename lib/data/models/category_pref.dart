/// Persönliche Overlay-Einstellung eines Nutzers zu einer Kategorie, siehe
/// Tabelle `category_prefs`. Überschreibt (falls gesetzt) die gruppenweiten
/// Werte der Kategorie in der Ansicht dieses Nutzers.
///
/// [active] / [sortOrder] sind `null`, wenn der Nutzer den Wert nicht
/// übersteuert (dann gilt der Wert der Kategorie). [hidden] blendet die
/// Kategorie für diesen Nutzer aus (reversibel).
class CategoryPref {
  const CategoryPref({
    required this.categoryId,
    this.active,
    this.sortOrder,
    this.hidden = false,
  });

  final String categoryId;
  final bool? active;
  final int? sortOrder;
  final bool hidden;

  factory CategoryPref.fromJson(Map<String, dynamic> json) => CategoryPref(
    categoryId: json['category_id'] as String,
    active: json['active'] as bool?,
    sortOrder: (json['sort_order'] as num?)?.toInt(),
    hidden: (json['hidden'] as bool?) ?? false,
  );
}
