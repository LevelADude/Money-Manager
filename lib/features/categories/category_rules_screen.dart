import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/category.dart';
import '../../shared/category_icons.dart';
import 'category_providers.dart';

/// Verwaltung der Auto-Kategorisierungs-Regeln (Stichwort -> Kategorie).
class CategoryRulesScreen extends ConsumerWidget {
  const CategoryRulesScreen({super.key});

  Future<void> _addRule(BuildContext context, WidgetRef ref) async {
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
          title: const Text('Neue Regel'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: keywordCtrl,
                autofocus: true,
                decoration: const InputDecoration(
                  labelText: 'Stichwort (im Titel enthalten)',
                  hintText: 'z. B. Aldi',
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: categoryId,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Kategorie'),
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
                child: const Text('Abbrechen')),
            FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Anlegen')),
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

    return Scaffold(
      appBar: AppBar(title: const Text('Auto-Kategorien')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _addRule(context, ref),
        icon: const Icon(Icons.add),
        label: const Text('Regel'),
      ),
      body: rulesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Fehler: $e')),
        data: (rules) {
          if (rules.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                    'Noch keine Regeln.\n\nLege fest, dass z. B. Titel mit '
                    '„Aldi" automatisch der Kategorie „Lebensmittel" '
                    'zugeordnet werden.',
                    textAlign: TextAlign.center),
              ),
            );
          }
          return ListView(
            children: [
              for (final r in rules)
                ListTile(
                  leading: const Icon(Icons.bolt_outlined),
                  title: Text('enthält „${r.keyword}"'),
                  subtitle: Text('→ ${catNames[r.categoryId] ?? 'Kategorie'}'),
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
