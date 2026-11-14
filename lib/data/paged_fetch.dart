/// Ab dieser Zeilenzahl gilt ein Stream-Ergebnis als möglicherweise
/// abgeschnitten. Die Supabase-API liefert pro Abfrage nur eine begrenzte
/// Zeilenzahl (Standard 1000); der Wert liegt bewusst deutlich darunter.
const kStreamRecheckThreshold = 500;

/// Zeilen je Seite beim seitenweisen Nachladen.
const kFetchPageSize = 1000;

/// Lädt ALLE Zeilen seitenweise. [fetchPage] bekommt den inklusiven Bereich
/// `from..to` und muss stabil sortiert liefern (z. B. zusätzlich nach `id`).
///
/// Weitergezählt wird um die tatsächlich erhaltene Zeilenzahl, bis eine Seite
/// leer ist. So bleibt das Ergebnis vollständig, auch wenn der Server weniger
/// Zeilen pro Abfrage liefert als angefragt.
Future<List<Map<String, dynamic>>> fetchAllPages(
  Future<List<Map<String, dynamic>>> Function(int from, int to) fetchPage, {
  int pageSize = kFetchPageSize,
}) async {
  final out = <Map<String, dynamic>>[];
  while (true) {
    final page = await fetchPage(out.length, out.length + pageSize - 1);
    if (page.isEmpty) return out;
    out.addAll(page);
  }
}

/// Liefert [streamed] unverändert, solange es sicher vollständig ist; sonst
/// den seitenweise nachgeladenen Gesamtstand. Schlägt das Nachladen fehl
/// (z. B. offline), bleibt es beim Stream-Stand.
Future<List<Map<String, dynamic>>> completeRows(
  List<Map<String, dynamic>> streamed,
  Future<List<Map<String, dynamic>>> Function(int from, int to) fetchPage, {
  int threshold = kStreamRecheckThreshold,
}) async {
  if (streamed.length < threshold) return streamed;
  try {
    return await fetchAllPages(fetchPage);
  } catch (_) {
    return streamed;
  }
}
