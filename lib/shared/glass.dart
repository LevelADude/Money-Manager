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
    this.onLongPress,
    this.shape = const StadiumBorder(),
    this.focusColor,
  });

  final Widget child;

  /// Fokusfarbe, wenn der Hintergrund selbst die Akzentfarbe ist.
  final Color? focusColor;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
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
          focusColor: widget.focusColor,
          onTap: widget.onTap,
          onLongPress: widget.onLongPress,
          onTapDown: (_) => _set(true),
          onTapUp: (_) => _set(false),
          onTapCancel: () => _set(false),
          child: widget.child,
        ),
      ),
    );
  }
}

/// Öffnet ein Bottom-Sheet als dicke Glasfläche der Bedienebene: oben
/// abgerundet, mit Griff, über der Navigation (Root-Navigator). Einzige
/// Stelle, an der Sheets geöffnet werden – so sehen alle gleich aus.
///
/// Parameter wie bei [showModalBottomSheet]; Griff und Form sind fest.
Future<T?> showGlassSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool isScrollControlled = false,
  bool useSafeArea = false,
  BoxConstraints? constraints,
}) {
  const radius = BorderRadius.vertical(top: Radius.circular(32));
  return showModalBottomSheet<T>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: isScrollControlled,
    useSafeArea: useSafeArea,
    constraints: constraints,
    // Fläche, Schatten und Griff kommen vom Glas, nicht vom Material-Sheet.
    backgroundColor: Colors.transparent,
    elevation: 0,
    showDragHandle: false,
    shape: const RoundedRectangleBorder(borderRadius: radius),
    clipBehavior: Clip.none,
    builder: (ctx) => Glass(
      thick: true,
      borderRadius: radius,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _SheetGrabber(),
          // Eigenes Material, damit Listenzeilen ihre Tinte auf dem Glas
          // malen statt dahinter.
          Flexible(
            child: Material(
              type: MaterialType.transparency,
              child: builder(ctx),
            ),
          ),
        ],
      ),
    ),
  );
}

class _SheetGrabber extends StatelessWidget {
  const _SheetGrabber();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 38,
        height: 5,
        margin: const EdgeInsets.only(top: 10, bottom: 8),
        decoration: BoxDecoration(
          color: Theme.of(
            context,
          ).colorScheme.onSurfaceVariant.withValues(alpha: .35),
          borderRadius: BorderRadius.circular(3),
        ),
      ),
    );
  }
}
