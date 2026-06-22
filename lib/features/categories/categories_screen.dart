import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/category.dart';
import '../../l10n/app_localizations.dart';
import '../../shared/category_icons.dart';
import 'category_providers.dart';

/// Gruppenweite Kategorien verwalten (anlegen / aktiv schalten / löschen /
/// Reihenfolge per Drag&Drop festlegen).
class CategoriesScreen extends ConsumerWidget {
  const CategoriesScreen({super.key});

  Future<void> _addDialog(BuildContext context, WidgetRef ref) async {
    final l = AppLocalizations.of(context);
    final controller = TextEditingController();
    var kind = CategoryKind.expense;
    final result = await showDialog<({String name, CategoryKind kind})>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: Text(l.newCategory),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: controller,
                autofocus: true,
                decoration: InputDecoration(labelText: l.name),
              ),
              const SizedBox(height: 16),
              SegmentedButton<CategoryKind>(
                segments: [
                  ButtonSegment(
                    value: CategoryKind.expense,
                    label: Text(l.expenseSingular),
                  ),
                  ButtonSegment(
                    value: CategoryKind.income,
                    label: Text(l.incomeSingular),
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
              child: Text(l.cancel),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, (
                name: controller.text.trim(),
                kind: kind,
              )),
              child: Text(l.create),
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
    final l = AppLocalizations.of(context);
    final catsAsync = ref.watch(categoriesProvider);
    return Scaffold(
      appBar: AppBar(title: Text(l.moreCategories)),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _addDialog(context, ref),
        icon: const Icon(Icons.add),
        label: Text(l.category),
      ),
      body: catsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text(l.errorWith(e))),
        data: (items) {
          final expense = items
              .where((c) => c.kind == CategoryKind.expense)
              .toList();
          final income = items
              .where((c) => c.kind == CategoryKind.income)
              .toList();
          return ListView(
            children: [
              _SectionHeader(l.expenses),
              _ReorderableCats(items: expense),
              _SectionHeader(l.income),
              _ReorderableCats(items: income),
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
      child: Text(
        title,
        style: Theme.of(
          context,
        ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
      ),
    );
  }
}

/// Sortierbare Liste der Kategorien einer Art. Hält eine lokale Kopie, damit
/// das Verschieben sofort flüssig wirkt (ohne auf den Server-Stream zu warten).
class _ReorderableCats extends ConsumerStatefulWidget {
  const _ReorderableCats({required this.items});

  final List<Category> items;

  @override
  ConsumerState<_ReorderableCats> createState() => _ReorderableCatsState();
}

class _ReorderableCatsState extends ConsumerState<_ReorderableCats> {
  late List<Category> _local = [...widget.items];

  @override
  void didUpdateWidget(_ReorderableCats old) {
    super.didUpdateWidget(old);
    final newIds = widget.items.map((c) => c.id).toList();
    final curIds = _local.map((c) => c.id).toList();
    if (_sameOrder(newIds, curIds)) {
      // Gleiche Reihenfolge: nur Feldwerte (Name/aktiv) übernehmen.
      _local = [
        for (final id in curIds) widget.items.firstWhere((c) => c.id == id),
      ];
    } else {
      // Server-Reihenfolge/Bestand hat sich geändert -> übernehmen.
      _local = [...widget.items];
    }
  }

  bool _sameOrder(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  // onReorderItem liefert newIndex bereits passend zum entfernten Element.
  Future<void> _onReorder(int oldIndex, int newIndex) async {
    setState(() {
      final moved = _local.removeAt(oldIndex);
      _local.insert(newIndex, moved);
    });
    await ref.read(categoryRepositoryProvider).reorder([
      for (var i = 0; i < _local.length; i++) (id: _local[i].id, sortOrder: i),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    return ReorderableListView.builder(
      shrinkWrap: true,
      primary: false,
      physics: const NeverScrollableScrollPhysics(),
      buildDefaultDragHandles: false,
      itemCount: _local.length,
      onReorderItem: _onReorder,
      itemBuilder: (ctx, i) => _CategoryTile(
        key: ValueKey(_local[i].id),
        category: _local[i],
        index: i,
      ),
    );
  }
}

class _CategoryTile extends ConsumerWidget {
  const _CategoryTile({super.key, required this.category, required this.index});

  final Category category;
  final int index;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    return ListTile(
      leading: Icon(iconForToken(category.icon)),
      title: Text(category.name),
      subtitle: Text(category.isPreset ? l.preset : l.custom),
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
            tooltip: l.delete,
            icon: const Icon(Icons.delete_outline),
            onPressed: () => ref
                .read(categoryRepositoryProvider)
                .deleteCategory(category.id),
          ),
          ReorderableDragStartListener(
            index: index,
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 8),
              child: Icon(Icons.drag_handle),
            ),
          ),
        ],
      ),
    );
  }
}
