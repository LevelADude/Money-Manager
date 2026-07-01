import 'package:http/http.dart' as http;

import 'db_connection_file.dart';

/// Warum das Holen der Verbindung von der Web-Version fehlgeschlagen ist.
/// Wird von der UI in eine lokalisierte Fehlermeldung uebersetzt.
enum RemoteConnectionError {
  emptyLink,
  invalidLink,
  unreachable,
  httpError,
  notConnected,
}

class RemoteConnectionException implements Exception {
  RemoteConnectionException(this.kind, {this.detail});

  final RemoteConnectionError kind;
  final String? detail;
}

/// Holt die Datenbank-Verbindung von einer bereits verbundenen Web-Version
/// dieser App (z. B. auf GitHub Pages) - liest deren fest eingecheckte
/// `connection.json` per HTTP, statt URL + Key manuell abzutippen.
///
/// [link] darf ein Kurzlink (z. B. git.io) oder die volle Web-URL sein: Der
/// erste Request folgt Redirects und liefert die tatsaechliche Basis-URL,
/// darunter liegt die Datei unter `assets/assets/db_connection/connection.json`
/// (Flutter-Web verdoppelt das "assets"-Praefix fuer Assets aus dem
/// pubspec-"assets:"-Abschnitt).
class RemoteConnection {
  const RemoteConnection._();

  static Future<({String url, String anonKey})> fetch(String link) async {
    final input = link.trim();
    if (input.isEmpty) {
      throw RemoteConnectionException(RemoteConnectionError.emptyLink);
    }

    Uri uri;
    try {
      uri = Uri.parse(input.contains('://') ? input : 'https://$input');
      if (uri.host.isEmpty) throw const FormatException();
    } catch (_) {
      throw RemoteConnectionException(RemoteConnectionError.invalidLink);
    }

    final base = await _resolveBase(uri);
    final manifestUrl = base.resolve(
      'assets/assets/db_connection/connection.json',
    );

    final http.Response response;
    try {
      response = await http
          .get(manifestUrl)
          .timeout(const Duration(seconds: 12));
    } catch (e) {
      throw RemoteConnectionException(
        RemoteConnectionError.unreachable,
        detail: '$e',
      );
    }
    if (response.statusCode != 200) {
      throw RemoteConnectionException(
        RemoteConnectionError.httpError,
        detail: '${response.statusCode}',
      );
    }

    final parsed = DbConnectionFile.parse(response.body);
    if (parsed == null) {
      throw RemoteConnectionException(RemoteConnectionError.notConnected);
    }
    return parsed;
  }

  /// Folgt Redirects (z. B. git.io -> github.io) und liefert die
  /// resultierende Basis-URL (ohne Dateiname, mit abschliessendem "/").
  static Future<Uri> _resolveBase(Uri input) async {
    final http.Response response;
    try {
      response = await http.head(input).timeout(const Duration(seconds: 12));
    } catch (e) {
      throw RemoteConnectionException(
        RemoteConnectionError.unreachable,
        detail: '$e',
      );
    }
    final resolved = response.request?.url ?? input;
    var path = resolved.path;
    if (!path.endsWith('/')) {
      final idx = path.lastIndexOf('/');
      path = idx >= 0 ? path.substring(0, idx + 1) : '/';
    }
    return resolved.replace(path: path, query: '', fragment: '');
  }
}
