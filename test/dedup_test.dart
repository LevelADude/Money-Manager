import 'package:flutter_test/flutter_test.dart';
import 'package:money_manager/data/local/app_cache.dart';

void main() {
  group('dedupRowsById', () {
    test('entfernt doppelte Zeilen mit gleicher id (erste gewinnt)', () {
      final rows = [
        {'id': 'a', 'name': 'erste'},
        {'id': 'b', 'name': 'zwei'},
        {'id': 'a', 'name': 'doppelt'},
      ];
      final out = dedupRowsById(rows);
      expect(out.length, 2);
      expect(out[0]['name'], 'erste'); // erste Variante bleibt
      expect(out[1]['id'], 'b');
    });

    test('behaelt Reihenfolge ohne Duplikate bei', () {
      final rows = [
        {'id': '1'},
        {'id': '2'},
        {'id': '3'},
      ];
      expect(dedupRowsById(rows).map((r) => r['id']).toList(), ['1', '2', '3']);
    });

    test('leere Liste bleibt leer', () {
      expect(dedupRowsById([]), isEmpty);
    });

    test('mehrfach dieselbe id wird auf eine reduziert', () {
      final rows = [
        {'id': 'x'},
        {'id': 'x'},
        {'id': 'x'},
      ];
      expect(dedupRowsById(rows).length, 1);
    });
  });
}
