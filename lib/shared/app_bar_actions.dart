import 'package:flutter/material.dart';

import 'responsive.dart';

/// Seltener genutzte Aktion der Kopfzeile.
typedef SecondaryAction = ({
  IconData icon,
  String label,
  VoidCallback? onPressed,
});

/// Aktionen der Kopfzeile: breit alle als Symbolknöpfe, auf Telefonbreite
/// wandern die [secondary] in ein „⋮"-Menü, damit der Titel nicht gekürzt
/// wird (z. B. „Ko…" statt „Konten").
List<Widget> responsiveActions(
  BuildContext context, {
  required List<Widget> primary,
  required List<SecondaryAction> secondary,
}) {
  if (context.isWide || secondary.isEmpty) {
    return [
      ...primary,
      for (final a in secondary)
        IconButton(
          tooltip: a.label,
          icon: Icon(a.icon),
          onPressed: a.onPressed,
        ),
    ];
  }
  return [
    ...primary,
    PopupMenuButton<int>(
      tooltip: MaterialLocalizations.of(context).moreButtonTooltip,
      icon: const Icon(Icons.more_vert),
      onSelected: (i) => secondary[i].onPressed?.call(),
      itemBuilder: (context) => [
        for (final (i, a) in secondary.indexed)
          PopupMenuItem<int>(
            value: i,
            enabled: a.onPressed != null,
            child: Row(
              children: [
                Icon(a.icon, size: 20),
                const SizedBox(width: 12),
                Text(a.label),
              ],
            ),
          ),
      ],
    ),
  ];
}
