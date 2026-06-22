import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Eingabe für Tags (Schlagworte) als Chips. Tippen + Enter/Komma fügt einen
/// Tag hinzu; vorhandene Tags der Gruppe werden als anklickbare Vorschläge
/// angeboten.
class TagEditor extends StatefulWidget {
  const TagEditor({
    super.key,
    required this.tags,
    required this.onChanged,
    this.suggestions = const [],
  });

  final List<String> tags;
  final ValueChanged<List<String>> onChanged;
  final List<String> suggestions;

  @override
  State<TagEditor> createState() => _TagEditorState();
}

class _TagEditorState extends State<TagEditor> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _add(String raw) {
    final tag = raw.trim();
    if (tag.isEmpty) return;
    final exists = widget.tags.any((t) => t.toLowerCase() == tag.toLowerCase());
    if (!exists) {
      widget.onChanged([...widget.tags, tag]);
    }
    _controller.clear();
    setState(() {});
  }

  void _remove(String tag) {
    widget.onChanged(widget.tags.where((t) => t != tag).toList());
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final input = _controller.text.trim().toLowerCase();
    final suggestions = widget.suggestions
        .where(
          (s) =>
              !widget.tags.any((t) => t.toLowerCase() == s.toLowerCase()) &&
              (input.isEmpty || s.toLowerCase().contains(input)),
        )
        .take(8)
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (widget.tags.isNotEmpty)
          Wrap(
            spacing: 6,
            runSpacing: 0,
            children: [
              for (final tag in widget.tags)
                InputChip(label: Text(tag), onDeleted: () => _remove(tag)),
            ],
          ),
        TextField(
          controller: _controller,
          textInputAction: TextInputAction.done,
          decoration: const InputDecoration(
            labelText: 'Tags (z. B. Urlaub, Geschäftlich)',
            hintText: 'Tag eingeben und Enter',
            prefixIcon: Icon(Icons.sell_outlined),
          ),
          inputFormatters: [
            // Komma trennt sofort einen Tag ab.
            TextInputFormatter.withFunction((oldV, newV) {
              if (newV.text.contains(',')) {
                final parts = newV.text.split(',');
                for (final p in parts) {
                  _add(p);
                }
                return const TextEditingValue(text: '');
              }
              return newV;
            }),
          ],
          onChanged: (_) => setState(() {}),
          onSubmitted: _add,
        ),
        if (suggestions.isNotEmpty) ...[
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 0,
            children: [
              for (final s in suggestions)
                ActionChip(
                  label: Text(s),
                  avatar: const Icon(Icons.add, size: 16),
                  onPressed: () => _add(s),
                ),
            ],
          ),
        ],
      ],
    );
  }
}
