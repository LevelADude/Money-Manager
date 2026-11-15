import 'package:flutter/material.dart';

/// Begrenzt die Breite des Inhalts und zentriert ihn auf breiten Bildschirmen
/// (Tablet/Laptop/Monitor). Auf schmalen Geräten (Handy) ist es ein No-Op,
/// weil die verfügbare Breite kleiner als [maxWidth] ist.
///
/// Verhindert, dass Formulare/Listen auf großen Monitoren unschön über die
/// gesamte Breite gezogen werden.
class MaxWidthBox extends StatelessWidget {
  const MaxWidthBox({super.key, required this.child, this.maxWidth = 860});

  final Widget child;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: child,
      ),
    );
  }
}

/// Praktische Breakpoints für responsives Layout.
extension ResponsiveContext on BuildContext {
  double get screenWidth => MediaQuery.sizeOf(this).width;

  /// Seitliche Navigation statt unterer Leiste.
  bool get isWide => screenWidth >= 640;

  /// Sehr breit (Monitor): NavigationRail mit Beschriftung neben den Icons.
  bool get isExtraWide => screenWidth >= 1200;

  /// Platz, den die schwebende Glas-Leiste unten überdeckt (0 auf Desktop).
  /// Scrollbare Inhalte hängen ihn an, damit sie unter der Leiste
  /// durchlaufen und das Ende trotzdem erreichbar bleibt.
  double get barInset => MediaQuery.paddingOf(this).bottom;
}

extension BarInsetPadding on EdgeInsets {
  /// Dieses Padding plus der Platz unter der Glas-Leiste.
  EdgeInsets withBarInset(BuildContext context) =>
      copyWith(bottom: bottom + context.barInset);
}
