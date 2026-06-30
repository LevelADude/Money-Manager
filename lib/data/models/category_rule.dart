/// Regel für Auto-Kategorisierung: Titel enthält [keyword] -> [categoryId].
class CategoryRule {
  const CategoryRule({
    required this.id,
    required this.keyword,
    required this.categoryId,
  });

  final String id;
  final String keyword;
  final String categoryId;

  factory CategoryRule.fromJson(Map<String, dynamic> json) => CategoryRule(
    id: json['id'] as String,
    keyword: (json['keyword'] as String?) ?? '',
    categoryId: json['category_id'] as String,
  );
}
