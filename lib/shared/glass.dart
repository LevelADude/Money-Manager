import 'dart:ui';

import 'package:flutter/material.dart';

import '../core/theme.dart';

/// Glasfläche der Bedienebene (Tableiste, Seitenleiste, schwebende Knöpfe).
///
/// Nur für Bedienelemente gedacht, nie für Inhalt: Inhaltskacheln bleiben
/// deckend, sonst leidet die Lesbarkeit und jede weitere Unschärfe kostet auf
/// dem Handy Bildrate. [thick] für große Flächen (stärkere Unschärfe, dichter).
///
/// Bei „Kontrast erhöhen" wird die Fläche deckend, ohne Unschärfe.
class Glass extends StatelessWidget {
  const Glass({
    super.key,
    required this.child,
    this.borderRadius = const BorderRadius.all(Radius.circular(28)),
    this.thick = false,
    this.padding = EdgeInsets.zero,
  });

  final Widget child;
  final BorderRadius borderRadius;
  final bool thick;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final solid = MediaQuery.highContrastOf(context);
    final sigma = thick ? 30.0 : 20.0;

    final surface = DecoratedBox(
      decoration: BoxDecoration(
        color: solid ? c.card : (thick ? c.glassThick : c.glass),
        borderRadius: borderRadius,
        border: Border.all(color: solid ? c.hairline : c.glassEdge),
      ),
      child: Padding(padding: padding, child: child),
    );

    return DecoratedBox(
      // Schatten außerhalb des Zuschnitts, sonst würde er abgeschnitten.
      decoration: BoxDecoration(
        borderRadius: borderRadius,
        boxShadow: [
          BoxShadow(
            color: c.glassShadow,
            blurRadius: thick ? 36 : 28,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: borderRadius,
        child: solid
            ? surface
            : BackdropFilter(
                filter: ImageFilter.blur(sigmaX: sigma, sigmaY: sigma),
                child: surface,
              ),
      ),
    );
  }
}

/// Drückt sein Kind beim Berühren leicht ein (Rückmeldung sofort beim
/// Aufsetzen des Fingers, nicht erst beim Loslassen) und löst [onTap] aus.
class PressScale extends StatefulWidget {
  const PressScale({
    super.key,
    required this.child,
    required this.onTap,
    this.shape = const StadiumBorder(),
  });

  final Widget child;
  final VoidCallback? onTap;
  final ShapeBorder shape;

  @override
  State<PressScale> createState() => _PressScaleState();
}

class _PressScaleState extends State<PressScale> {
  bool _down = false;

  void _set(bool v) {
    if (_down != v) setState(() => _down = v);
  }

  @override
  Widget build(BuildContext context) {
    final reduce = MediaQuery.disableAnimationsOf(context);
    return AnimatedScale(
      scale: _down && !reduce ? .94 : 1,
      duration: const Duration(milliseconds: 110),
      curve: Curves.easeOut,
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          customBorder: widget.shape,
          onTap: widget.onTap,
          onTapDown: (_) => _set(true),
          onTapUp: (_) => _set(false),
          onTapCancel: () => _set(false),
          child: widget.child,
        ),
      ),
    );
  }
}
