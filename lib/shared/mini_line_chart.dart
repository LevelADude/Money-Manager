import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Kleines Liniendiagramm (mit Flächenfüllung + Null-Linie) für Zeitreihen.
class MiniLineChart extends StatelessWidget {
  const MiniLineChart({
    super.key,
    required this.values,
    required this.color,
    this.height = 120,
    this.labels = const [],
  });

  final List<int> values;
  final Color color;
  final double height;

  /// Optionale Beschriftungen unter dem Diagramm (gleichmäßig verteilt).
  final List<String> labels;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: CustomPaint(
        size: Size.infinite,
        painter: _LineChartPainter(
          values: values,
          lineColor: color,
          gridColor: Theme.of(context).dividerColor,
          labelColor: Theme.of(context).hintColor,
          labels: labels,
        ),
      ),
    );
  }
}

class _LineChartPainter extends CustomPainter {
  _LineChartPainter({
    required this.values,
    required this.lineColor,
    required this.gridColor,
    required this.labelColor,
    required this.labels,
  });

  final List<int> values;
  final Color lineColor;
  final Color gridColor;
  final Color labelColor;
  final List<String> labels;

  @override
  void paint(Canvas canvas, Size size) {
    if (values.length < 2) return;
    final labelH = labels.isEmpty ? 0.0 : 16.0;
    final chartH = size.height - labelH;
    final maxV = values.reduce(math.max);
    final minV = values.reduce(math.min);
    final range = (maxV - minV) == 0 ? 1 : (maxV - minV);
    double x(int i) => size.width * i / (values.length - 1);
    double y(int v) => chartH - (v - minV) / range * (chartH - 4) - 2;

    // Null-Linie.
    if (minV < 0 && maxV > 0) {
      final zy = y(0);
      canvas.drawLine(Offset(0, zy), Offset(size.width, zy),
          Paint()..color = gridColor..strokeWidth = 1);
    }

    final line = Path()..moveTo(x(0), y(values.first));
    for (var i = 1; i < values.length; i++) {
      line.lineTo(x(i), y(values[i]));
    }

    // Flächenfüllung.
    final fill = Path.from(line)
      ..lineTo(x(values.length - 1), chartH)
      ..lineTo(x(0), chartH)
      ..close();
    canvas.drawPath(fill, Paint()..color = lineColor.withValues(alpha: 0.12));

    canvas.drawPath(
      line,
      Paint()
        ..color = lineColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..strokeJoin = StrokeJoin.round,
    );

    // Letzter Punkt.
    canvas.drawCircle(
        Offset(x(values.length - 1), y(values.last)), 3.5, Paint()..color = lineColor);

    // Labels (erste, mittlere, letzte – um Überlappung zu vermeiden).
    if (labels.isNotEmpty && labels.length == values.length) {
      final idxs = {0, values.length ~/ 2, values.length - 1};
      for (final i in idxs) {
        final tp = TextPainter(
          text: TextSpan(
              text: labels[i],
              style: TextStyle(color: labelColor, fontSize: 9)),
          textDirection: TextDirection.ltr,
        )..layout();
        var dx = x(i) - tp.width / 2;
        dx = dx.clamp(0.0, size.width - tp.width);
        tp.paint(canvas, Offset(dx, chartH + 2));
      }
    }
  }

  @override
  bool shouldRepaint(covariant _LineChartPainter old) => true;
}
