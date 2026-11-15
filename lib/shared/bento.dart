import 'package:flutter/material.dart';

import '../core/theme.dart';

/// Bausteine des Bento-Layouts: deckende Inhaltskacheln mit einheitlicher
/// Form, Schrift und Zeilenaufbau. Bewusst ohne Glas und ohne Unschärfe –
/// Glas gehört nur auf die Bedienebene (siehe `glass.dart`).

/// Schriftstile und Maße, die alle Kacheln teilen.
abstract final class Bento {
  /// Abstand zwischen Kacheln.
  static const double gap = 12;

  /// Seitlicher Rand der Kachelfläche zum Bildschirm.
  static const double margin = 16;

  /// Eckenradius der Kacheln.
  static const double radius = 22;

  /// Ab dieser Inhaltsbreite vier statt zwei Spalten.
  static const double wideBreakpoint = 600;

  /// Kleine Überschrift einer Kachel.
  static TextStyle label(BuildContext context) {
    final t = Theme.of(context);
    return t.textTheme.bodySmall!.copyWith(
      fontSize: 12.5,
      fontWeight: FontWeight.w500,
      color: t.colorScheme.onSurfaceVariant,
    );
  }

  /// Kennzahl einer Kachel.
  static TextStyle number(BuildContext context, {double size = 20}) =>
      Theme.of(context).textTheme.titleLarge!.copyWith(
        fontSize: size,
        fontWeight: FontWeight.w600,
        letterSpacing: size >= 32 ? -size * .03 : -size * .02,
        height: 1.15,
      );

  /// Erläuterung unter einer Kennzahl.
  static TextStyle sub(BuildContext context) {
    final t = Theme.of(context);
    return t.textTheme.bodySmall!.copyWith(
      fontSize: 12.5,
      color: t.colorScheme.onSurfaceVariant,
    );
  }

  /// Überschrift eines Abschnitts über einer Kachel (Tag, Kontotyp).
  static TextStyle section(BuildContext context) {
    final t = Theme.of(context);
    return t.textTheme.bodySmall!.copyWith(
      fontSize: 13,
      fontWeight: FontWeight.w600,
      color: t.colorScheme.onSurfaceVariant,
    );
  }
}

/// Deckende Inhaltskachel. Mit [onTap] reagiert die ganze Fläche.
class BentoTile extends StatelessWidget {
  const BentoTile({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.fromLTRB(16, 14, 16, 14),
    this.onTap,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final content = Padding(padding: padding, child: child);
    return Material(
      color: c.card,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Bento.radius),
        side: BorderSide(color: c.hairline),
      ),
      child: onTap == null ? content : InkWell(onTap: onTap, child: content),
    );
  }
}

/// Summen-Kachel: Überschrift, Kennzahl, optional Erläuterung.
class BentoStat extends StatelessWidget {
  const BentoStat({
    super.key,
    required this.label,
    required this.value,
    this.trailing,
    this.sub,
    this.onTap,
  });

  final String label;

  /// Die Kennzahl; erbt [Bento.number] als Standardstil.
  final Widget value;

  /// Rechts neben der Überschrift (Chip, Icon).
  final Widget? trailing;
  final Widget? sub;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return BentoTile(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: Bento.label(context),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              ?trailing,
            ],
          ),
          const SizedBox(height: 2),
          // Lange Beträge schrumpfen, statt umzubrechen oder abzuschneiden.
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: DefaultTextStyle.merge(
              style: Bento.number(context),
              child: value,
            ),
          ),
          if (sub != null)
            DefaultTextStyle.merge(style: Bento.sub(context), child: sub!),
        ],
      ),
    );
  }
}

/// Getönter Kreis hinter einem Emoji oder Icon.
class BentoGlyph extends StatelessWidget {
  const BentoGlyph({super.key, required this.child, this.size = 42});

  final Widget child;
  final double size;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.of(context).chip,
        shape: BoxShape.circle,
      ),
      child: IconTheme.merge(
        data: IconThemeData(
          size: size * .5,
          color: t.colorScheme.onSurfaceVariant,
        ),
        child: child,
      ),
    );
  }
}

/// Zeile in einer Listen-Kachel: Kreis, Titel mit Unterzeile, Betrag rechts.
class BentoRow extends StatelessWidget {
  const BentoRow({
    super.key,
    required this.title,
    this.leading,
    this.subtitle,
    this.columns = const [],
    this.trailing,
    this.onTap,
    this.padding = const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
  });

  final Widget? leading;
  final Widget title;
  final Widget? subtitle;

  /// Zusatzspalten zwischen Titel und Betrag (Desktop: Kategorie, Konto).
  final List<Widget> columns;
  final Widget? trailing;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final ink2 = t.colorScheme.onSurfaceVariant;
    final titleStyle = t.textTheme.bodyLarge!.copyWith(
      fontSize: 15,
      fontWeight: FontWeight.w600,
    );
    final subStyle = t.textTheme.bodySmall!.copyWith(fontSize: 13, color: ink2);
    final row = Padding(
      padding: padding,
      child: Row(
        children: [
          if (leading != null) ...[leading!, const SizedBox(width: 12)],
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                DefaultTextStyle.merge(
                  style: titleStyle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  child: title,
                ),
                if (subtitle != null)
                  DefaultTextStyle.merge(
                    style: subStyle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    child: subtitle!,
                  ),
              ],
            ),
          ),
          for (final col in columns) ...[
            const SizedBox(width: 12),
            Expanded(
              flex: 2,
              child: DefaultTextStyle.merge(
                style: subStyle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                child: col,
              ),
            ),
          ],
          if (trailing != null) ...[
            const SizedBox(width: 12),
            // Mit Zusatzspalten feste Mindestbreite, damit die Spalten in
            // allen Zeilen an derselben Stelle beginnen.
            ConstrainedBox(
              constraints: BoxConstraints(minWidth: columns.isEmpty ? 0 : 120),
              child: Align(
                alignment: Alignment.centerRight,
                widthFactor: 1,
                child: DefaultTextStyle.merge(
                  style: titleStyle,
                  textAlign: TextAlign.right,
                  child: trailing!,
                ),
              ),
            ),
          ],
        ],
      ),
    );
    return onTap == null ? row : InkWell(onTap: onTap, child: row);
  }
}

/// Kachel aus Zeilen, durch Haarlinien getrennt.
class BentoList extends StatelessWidget {
  const BentoList({super.key, required this.children, this.header});

  /// Optionale Kopfzeile innerhalb der Kachel.
  final Widget? header;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return BentoTile(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          ?header,
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0 || header != null) const Divider(height: 1),
            children[i],
          ],
        ],
      ),
    );
  }
}

/// Überschrift über einer Kachel: Bezeichnung links, Summe rechts.
class BentoSectionHeader extends StatelessWidget {
  const BentoSectionHeader({super.key, required this.label, this.trailing});

  final String label;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final style = Bento.section(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(6, 0, 6, 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: style,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (trailing != null)
            DefaultTextStyle.merge(style: style, child: trailing!),
        ],
      ),
    );
  }
}

/// Kleine getönte Marke (Veränderung, Anteil) neben einer Überschrift.
class BentoChip extends StatelessWidget {
  const BentoChip({super.key, required this.child, this.icon});

  final Widget child;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final s = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: ShapeDecoration(
        color: s.primaryContainer,
        shape: const StadiumBorder(),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: s.onPrimaryContainer),
            const SizedBox(width: 4),
          ],
          DefaultTextStyle.merge(
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: s.onPrimaryContainer,
            ),
            child: child,
          ),
        ],
      ),
    );
  }
}

/// Eine Zelle im [BentoGrid]. [span] gilt im schmalen Raster (2 Spalten),
/// [wideSpan] im breiten (4 Spalten).
class BentoCell {
  const BentoCell({required this.child, this.span = 1, int? wideSpan})
    : wideSpan = wideSpan ?? span;

  /// Volle Breite in beiden Rastern.
  const BentoCell.full({required this.child}) : span = 2, wideSpan = 4;

  final Widget child;
  final int span;
  final int wideSpan;
}

/// Raster aus Kacheln: zwei Spalten schmal, vier Spalten breit. Zellen werden
/// zeilenweise gepackt; Kacheln einer Zeile sind gleich hoch.
///
/// [stretch] abschalten, wenn Zellen keine intrinsische Höhe liefern können
/// (LayoutBuilder, Viewports) – dann richten sie sich oben aus.
class BentoGrid extends StatelessWidget {
  const BentoGrid({
    super.key,
    required this.cells,
    this.gap = Bento.gap,
    this.stretch = true,
  });

  final List<BentoCell> cells;
  final double gap;
  final bool stretch;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, box) {
        final wide = box.maxWidth >= Bento.wideBreakpoint;
        final cols = wide ? 4 : 2;
        final unit = (box.maxWidth - gap * (cols - 1)) / cols;

        final rows = <List<(BentoCell, int)>>[];
        var used = cols; // erzwingt die erste Zeile
        for (final cell in cells) {
          final span = (wide ? cell.wideSpan : cell.span).clamp(1, cols);
          if (used + span > cols) {
            rows.add([]);
            used = 0;
          }
          rows.last.add((cell, span));
          used += span;
        }

        Widget buildRow(List<(BentoCell, int)> row) {
          final r = Row(
            crossAxisAlignment: stretch
                ? CrossAxisAlignment.stretch
                : CrossAxisAlignment.start,
            children: [
              for (var i = 0; i < row.length; i++) ...[
                if (i > 0) SizedBox(width: gap),
                SizedBox(
                  // Abrunden, damit Rundungsfehler die Zeile nie überlaufen.
                  width:
                      ((unit * row[i].$2 + gap * (row[i].$2 - 1)) * 100)
                          .floorToDouble() /
                      100,
                  child: row[i].$1.child,
                ),
              ],
            ],
          );
          return stretch ? IntrinsicHeight(child: r) : r;
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < rows.length; i++) ...[
              if (i > 0) SizedBox(height: gap),
              buildRow(rows[i]),
            ],
          ],
        );
      },
    );
  }
}

/// Zwei gleich breite Spalten nebeneinander (breit) bzw. alles untereinander
/// (schmal). Für Kacheln sehr unterschiedlicher Höhe, etwa Diagramme.
class BentoColumns extends StatelessWidget {
  const BentoColumns({
    super.key,
    required this.left,
    required this.right,
    this.gap = Bento.gap,
  });

  final List<Widget> left;
  final List<Widget> right;
  final double gap;

  @override
  Widget build(BuildContext context) {
    Widget column(List<Widget> items) => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < items.length; i++) ...[
          if (i > 0) SizedBox(height: gap),
          items[i],
        ],
      ],
    );
    return LayoutBuilder(
      builder: (context, box) {
        if (box.maxWidth < Bento.wideBreakpoint) {
          // Schmal: abwechselnd links/rechts, damit die Reihenfolge der
          // breiten Ansicht (zeilenweise gelesen) erhalten bleibt.
          final merged = <Widget>[];
          for (var i = 0; i < left.length || i < right.length; i++) {
            if (i < left.length) merged.add(left[i]);
            if (i < right.length) merged.add(right[i]);
          }
          return column(merged);
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: column(left)),
            SizedBox(width: gap),
            Expanded(child: column(right)),
          ],
        );
      },
    );
  }
}
