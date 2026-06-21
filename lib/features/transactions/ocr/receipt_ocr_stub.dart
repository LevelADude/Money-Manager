import 'dart:typed_data';

import 'receipt_scan.dart';

/// Stub für Plattformen ohne On-Device-OCR (Web). Liefert nie ein Ergebnis.
const bool ocrSupported = false;

Future<ReceiptScan?> scanReceipt(Uint8List bytes, String extension) async =>
    null;
