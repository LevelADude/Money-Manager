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
}
