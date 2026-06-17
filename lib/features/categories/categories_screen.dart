import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/category.dart';
import '../../shared/category_icons.dart';
import 'category_providers.dart';

/// Gruppenweite Kategorien verwalten (anlegen / aktiv schalten / löschen).
class CategoriesScreen extends ConsumerWidget {
  const CategoriesScreen({super.key});

  Future<void> _addDialog(BuildContext context, WidgetRef ref) async {
    final controller = TextEditingController();
    var kind = CategoryKind.expense;
    final result = await showDialog<({String name, CategoryKind kind})>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: const Text('Neue Kategorie'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: controller,
                autofocus: true,
                decoration: const InputDecoration(labelText: 'Name'),
              ),
              const SizedBox(height: 16),
              SegmentedButton<CategoryKind>(
                segments: const [
                  ButtonSegment(
                      value: CategoryKind.expense, label: Text('Ausgabe')),
                  ButtonSegment(
                      value: CategoryKind.income, label: Text('Einnahme')),
                ],
                selected: {kind},
                onSelectionChanged: (s) => setState(() => kind = s.first),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Abbrechen'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(
                ctx,
                (name: controller.text.trim(), kind: kind),
              ),
              child: const Text('Anlegen'),
            ),
          ],
        ),
      ),
    );
    if (result != null && result.name.isNotEmpty) {
      await ref
          .read(categoryRepositoryProvider)
          .addCategory(name: result.name, kind: result.kind, icon: 'more');
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final catsAsync = ref.watch(categoriesProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Kategorien')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _addDialog(context, ref),
        icon: const Icon(Icons.add),
        label: const Text('Kategorie'),
      ),
      body: catsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Fehler: $e')),
        data: (items) {
          final expense = items.where((c) => c.kind == CategoryKind.expense).toList();
          final income = items.where((c) => c.kind == CategoryKind.income).toList();
          return ListView(
            children: [
              _SectionHeader('Ausgaben'),
              for (final c in expense) _CategoryTile(c),
              _SectionHeader('Einnahmen'),
              for (final c in income) _CategoryTile(c),
              const SizedBox(height: 80),
            ],
          );
        },
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.title);
  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Text(title,
          style: Theme.of(context)
              .textTheme
              .titleSmall
              ?.copyWith(fontWeight: FontWeight.bold)),
    );
  }
}

class _CategoryTile extends ConsumerWidget {
  const _CategoryTile(this.category);
  final Category category;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListTile(
      leading: Icon(iconForToken(category.icon)),
      title: Text(category.name),
      subtitle: Text(category.isPreset ? 'Vorlage' : 'Eigene'),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Switch(
            value: category.active,
            onChanged: (v) => ref
                .read(categoryRepositoryProvider)
                .setActive(id: category.id, active: v),
          ),
          IconButton(
            tooltip: 'Löschen',
            icon: const Icon(Icons.delete_outline),
            onPressed: () =>
                ref.read(categoryRepositoryProvider).deleteCategory(category.id),
          ),
        ],
      ),
    );
  }
}
