import 'package:flutter/foundation.dart';

/// Startzeit-Messung, nur aktiv mit `--dart-define=STARTUP_TRACE=true`.
/// Sonst entfernt der Compiler die Aufrufe (konstante Bedingung).
///
/// Jede Marke wird mit Millisekunden seit `main()` und der Uhrzeit
/// (Epoch-ms, zum Abgleich mit dem Prozess- bzw. Seitenstart) ausgegeben.
/// Wiederholte Marken werden nummeriert und nach [_maxPerLabel] verworfen.
const startupTraceEnabled = bool.fromEnvironment('STARTUP_TRACE');

const _maxPerLabel = 3;
final _clock = Stopwatch();
final _counts = <String, int>{};

void startupMark(String label, [String detail = '']) {
  if (!startupTraceEnabled) return;
  if (!_clock.isRunning) _clock.start();
  final n = (_counts[label] ?? 0) + 1;
  _counts[label] = n;
  if (n > _maxPerLabel) return;
  debugPrint(
    '[startup] $label #$n$detail: ${_clock.elapsedMilliseconds} ms '
    '(epoch ${DateTime.now().millisecondsSinceEpoch})',
  );
}

/// Markiert jede Ausgabe eines Streams (z. B. erst Cache, dann Server).
Stream<T> traceStream<T>(String label, Stream<T> source) {
  if (!startupTraceEnabled) return source;
  return source.map((v) {
    final size = v is List ? ' (${v.length})' : '';
    startupMark(label, size);
    return v;
  });
}
