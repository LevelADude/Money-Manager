import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

import 'receipt_parser.dart';
import 'receipt_scan.dart';

/// On-Device-OCR nur auf Android (ML Kit). Auf anderen nativen Plattformen
/// (z. B. Windows) ist diese Datei zwar einkompiliert, liefert aber `false`,
/// da kein ML-Kit-Backend existiert.
bool get ocrSupported => !kIsWeb && Platform.isAndroid;

/// Erkennt Text im Beleg-Bild und parst Betrag/Datum/Händler heraus.
/// Gibt null zurück, wenn nicht unterstützt, nichts erkannt oder ein Fehler
/// auftritt – die Buchung läuft dann ganz normal ohne Vorbefüllung weiter.
Future<ReceiptScan?> scanReceipt(Uint8List bytes, String extension) async {
  if (!ocrSupported) return null;
  Directory? tmpDir;
  TextRecognizer? recognizer;
  try {
    tmpDir = await Directory.systemTemp.createTemp('receipt_ocr');
    final ext = extension.toLowerCase().replaceAll(RegExp('[^a-z0-9]'), '');
    final file = File('${tmpDir.path}/scan.${ext.isEmpty ? 'jpg' : ext}');
    await file.writeAsBytes(bytes, flush: true);

    recognizer = TextRecognizer(script: TextRecognitionScript.latin);
    final result = await recognizer.processImage(InputImage.fromFilePath(file.path));
    final scan = parseReceiptText(result.text);
    return scan.hasAnything ? scan : null;
  } catch (_) {
    return null;
  } finally {
    await recognizer?.close();
    try {
      await tmpDir?.delete(recursive: true);
    } catch (_) {}
  }
}
