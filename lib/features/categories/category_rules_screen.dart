import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/category.dart';
import '../../l10n/app_localizations.dart';
import '../../shared/category_icons.dart';
import 'category_providers.dart';

/// Verwaltung der Auto-Kategorisierungs-Regeln (Stichwort -> Kategorie).
class CategoryRulesScreen extends ConsumerWidget {
  const CategoryRulesScreen({super.key});

  Future<void> _addRule(BuildContext context, WidgetRef ref) async {
    final l = AppLocalizations.of(context);
    final cats = (ref.read(categoriesProvider).asData?.value ??
            const <Category>[])
        .where((c) => c.active)
        .toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    if (cats.isEmpty) return;
    final keywordCtrl = TextEditingController();
    var categoryId = cats.first.id;

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: Text(l.newRule),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: keywordCtrl,
                autofocus: true,
                decoration: InputDecoration(
                  labelText: l.keywordLabel,
                  hintText: l.keywordHint,
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: categoryId,
                isExpanded: true,
                decoration: InputDecoration(labelText: l.category),
                items: [
                  for (final c in cats)
                    DropdownMenuItem(
                      value: c.id,
                      child: Row(
                        children: [
                          Icon(iconForToken(c.icon), size: 18),
                          const SizedBox(width: 8),
                          Flexible(
                              child: Text(c.name,
                                  overflow: TextOverflow.ellipsis)),
                        ],
                      ),
                    ),
                ],
                onChanged: (v) => setState(() => categoryId = v ?? categoryId),
              ),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text(l.cancel)),
            FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: Text(l.create)),
          ],
        ),
      ),
    );
    if (ok == true && keywordCtrl.text.trim().isNotEmpty) {
      await ref
          .read(categoryRepositoryProvider)
          .addRule(keyword: keywordCtrl.text.trim(), categoryId: categoryId);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rulesAsync = ref.watch(categoryRulesProvider);
    final catNames = ref.watch(categoryNamesProvider);
    final l = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(l.rulesTitle)),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _addRule(context, ref),
        icon: const Icon(Icons.add),
        label: Text(l.ruleFab),
      ),
      body: rulesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text(l.errorWith(e))),
        data: (rules) {
          if (rules.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(l.noRules, textAlign: TextAlign.center),
              ),
            );
          }
          return ListView(
            children: [
              for (final r in rules)
                ListTile(
                  leading: const Icon(Icons.bolt_outlined),
                  title: Text(l.containsKeyword(r.keyword)),
                  subtitle: Text('→ ${catNames[r.categoryId] ?? l.category}'),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_outline),
                    onPressed: () =>
                        ref.read(categoryRepositoryProvider).deleteRule(r.id),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}
