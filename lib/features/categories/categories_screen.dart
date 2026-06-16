import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/category.dart';
import 'category_providers.dart';

/// Kategorien eines Buchs verwalten (anlegen / löschen).
class CategoriesScreen extends ConsumerWidget {
  const CategoriesScreen({super.key, required this.ledgerId});

  final String ledgerId;

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
                    value: CategoryKind.expense,
                    label: Text('Ausgabe'),
                  ),
                  ButtonSegment(
                    value: CategoryKind.income,
                    label: Text('Einnahme'),
                  ),
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
      await ref.read(categoryRepositoryProvider).addCategory(
            ledgerId: ledgerId,
            name: result.name,
            kind: result.kind,
          );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cats = ref.watch(categoriesProvider(ledgerId));
    return Scaffold(
      appBar: AppBar(title: const Text('Kategorien')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _addDialog(context, ref),
        icon: const Icon(Icons.add),
        label: const Text('Kategorie'),
      ),
      body: cats.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Fehler: $e')),
        data: (items) {
          if (items.isEmpty) {
            return const Center(
              child: Text('Noch keine Kategorien. Lege unten welche an.'),
            );
          }
          return ListView.separated(
            itemCount: items.length,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (_, i) {
              final c = items[i];
              final income = c.kind == CategoryKind.income;
              return ListTile(
                leading: Icon(
                  income ? Icons.south_west : Icons.north_east,
                  color: income ? Colors.green.shade700 : Colors.red.shade700,
                ),
                title: Text(c.name),
                subtitle: Text(income ? 'Einnahme' : 'Ausgabe'),
                trailing: IconButton(
                  tooltip: 'Löschen',
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () =>
                      ref.read(categoryRepositoryProvider).deleteCategory(c.id),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
