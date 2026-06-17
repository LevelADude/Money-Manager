import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

/// Lädt Belege (Fotos) in den privaten Supabase-Storage-Bucket "receipts".
class ReceiptStorage {
  ReceiptStorage(this._client);

  final SupabaseClient _client;
  static const String bucket = 'receipts';

  /// Lädt Bytes hoch und gibt den Objektpfad zurück.
  Future<String> upload(Uint8List bytes, String extension) async {
    final ext = extension.toLowerCase();
    final uid = _client.auth.currentUser?.id ?? 'anon';
    final path = '$uid/${DateTime.now().millisecondsSinceEpoch}.$ext';
    final contentType = (ext == 'png') ? 'image/png' : 'image/jpeg';
    await _client.storage.from(bucket).uploadBinary(
          path,
          bytes,
          fileOptions: FileOptions(contentType: contentType, upsert: true),
        );
    return path;
  }

  /// Zeitlich begrenzte URL zum Anzeigen (Bucket ist privat).
  Future<String> signedUrl(String path) =>
      _client.storage.from(bucket).createSignedUrl(path, 60 * 60);

  Future<void> delete(String path) =>
      _client.storage.from(bucket).remove([path]);
}
