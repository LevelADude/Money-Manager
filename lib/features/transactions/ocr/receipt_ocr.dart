/// Plattform-Fassade für die Beleg-Texterkennung.
///
/// `dart.library.io` ist auf nativen Plattformen (Android/Windows) vorhanden,
/// auf Web nicht. So wird die ML-Kit-Implementierung NIE in den Web-Build
/// gezogen (ML Kit nutzt `dart:io` und unterstützt kein Web) – Web bekommt den
/// Stub. Auf Windows wird zwar die io-Variante kompiliert, liefert dort aber
/// `ocrSupported == false` (nur Android wird tatsächlich erkannt).
library;

export 'receipt_scan.dart';
export 'receipt_ocr_stub.dart'
    if (dart.library.io) 'receipt_ocr_mlkit.dart';
