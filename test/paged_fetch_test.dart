import 'package:flutter_test/flutter_test.dart';
import 'package:money_manager/data/paged_fetch.dart';

/// Simuliert einen Server mit [total] Zeilen, der pro Abfrage höchstens
/// [serverCap] Zeilen liefert.
Future<List<Map<String, dynamic>>> Function(int, int) _server(
  int total, {
  required int serverCap,
  List<int>? calls,
}) {
  return (from, to) async {
    calls?.add(from);
    final end = [
      to + 1,
      from + serverCap,
      total,
    ].reduce((a, b) => a < b ? a : b);
    return [
      for (var i = from; i < end; i++) {'id': i},
    ];
  };
}

void main() {
  test('lädt alle Seiten', () async {
    final rows = await fetchAllPages(_server(2500, serverCap: 1000));
    expect(rows.length, 2500);
    expect(rows.last['id'], 2499);
  });

  test(
    'bleibt vollständig, wenn der Server weniger liefert als angefragt',
    () async {
      final rows = await fetchAllPages(_server(1234, serverCap: 300));
      expect(rows.map((r) => r['id']), List.generate(1234, (i) => i));
    },
  );

  test('leere Tabelle', () async {
    expect(await fetchAllPages(_server(0, serverCap: 1000)), isEmpty);
  });

  test('unter der Schwelle wird nicht nachgeladen', () async {
    final calls = <int>[];
    final streamed = [
      for (var i = 0; i < 10; i++) <String, dynamic>{'id': i},
    ];
    final rows = await completeRows(
      streamed,
      _server(10, serverCap: 1000, calls: calls),
    );
    expect(identical(rows, streamed), isTrue);
    expect(calls, isEmpty);
  });

  test('abgeschnittener Stream-Stand wird vervollständigt', () async {
    final streamed = [
      for (var i = 0; i < 1000; i++) <String, dynamic>{'id': i},
    ];
    final rows = await completeRows(streamed, _server(1800, serverCap: 1000));
    expect(rows.length, 1800);
  });

  test('Fehler beim Nachladen: Stream-Stand bleibt', () async {
    final streamed = [
      for (var i = 0; i < 600; i++) <String, dynamic>{'id': i},
    ];
    final rows = await completeRows(
      streamed,
      (_, _) async => throw Exception('offline'),
    );
    expect(identical(rows, streamed), isTrue);
  });
}
