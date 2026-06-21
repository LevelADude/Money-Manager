import 'dart:typed_data';

import 'package:flutter/foundation.dart' show compute;
import 'package:image/image.dart' as img;

/// Ergebnis einer Beleg-Komprimierung: die (ggf. verkleinerten) Bytes plus die
/// passende Datei-Endung. Wurde das Bild als JPEG neu kodiert, ist [extension]
/// `jpg`; im Sicherheitsnetz-Fall sind es die unveränderten Originaldaten.
class CompressedImage {
  const CompressedImage(this.bytes, this.extension);

  final Uint8List bytes;
  final String extension;
}

/// Verkleinert ein Beleg-Bild vor dem Upload, um Storage zu sparen.
///
/// Skaliert auf [maxDimension] px (längste Kante) herunter und kodiert das
/// Ergebnis als JPEG ([quality] 0–100) → aus mehreren MB werden typischerweise
/// nur noch 100–300 kB. Läuft rein in Dart über [compute] in einem
/// Hintergrund-Isolate (UI bleibt flüssig) und funktioniert daher auf ALLEN
/// Plattformen — auch Web/PWA und Windows, wo der ImagePicker die
/// Größenparameter (maxWidth/maxHeight/imageQuality) ignoriert.
///
/// Sicherheitsnetz: Lässt sich das Bild nicht dekodieren oder würde das
/// Ergebnis nicht kleiner werden, werden die Originaldaten unverändert
/// zurückgegeben — ein Upload scheitert also nie an der Komprimierung.
Future<CompressedImage> compressReceipt(
  Uint8List bytes,
  String extension, {
  int maxDimension = 1600,
  int quality = 70,
}) {
  return compute(
    _compress,
    _CompressRequest(bytes, extension, maxDimension, quality),
  );
}

/// Eingabe für das Hintergrund-Isolate (muss zwischen Isolates kopierbar sein).
class _CompressRequest {
  const _CompressRequest(
      this.bytes, this.extension, this.maxDimension, this.quality);

  final Uint8List bytes;
  final String extension;
  final int maxDimension;
  final int quality;
}

/// Läuft im Hintergrund-Isolate. Fängt alle Fehler ab und liefert im Zweifel
/// die Originaldaten zurück.
CompressedImage _compress(_CompressRequest req) {
  final original = CompressedImage(req.bytes, req.extension);
  try {
    final decoded = img.decodeImage(req.bytes);
    if (decoded == null) return original;

    final longest =
        decoded.width > decoded.height ? decoded.width : decoded.height;
    final resized = longest > req.maxDimension
        ? img.copyResize(
            decoded,
            width: decoded.width >= decoded.height ? req.maxDimension : null,
            height: decoded.height > decoded.width ? req.maxDimension : null,
          )
        : decoded;

    final jpg = img.encodeJpg(resized, quality: req.quality);
    // Nur übernehmen, wenn das Bild dadurch tatsächlich kleiner wurde.
    if (jpg.length >= req.bytes.length) return original;
    return CompressedImage(jpg, 'jpg');
  } catch (_) {
    return original;
  }
}
