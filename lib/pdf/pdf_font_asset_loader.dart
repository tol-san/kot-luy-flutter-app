import 'dart:io';

import 'package:flutter/services.dart';

/// Loads font assets for PDF rendering, with a file-system fallback for tests.
class PdfFontAssetLoader {
  const PdfFontAssetLoader._();

  static Future<Uint8List> load(String path) async {
    try {
      final byteData = await rootBundle.load(path);
      return byteData.buffer.asUint8List(
        byteData.offsetInBytes,
        byteData.lengthInBytes,
      );
    } catch (_) {
      return File(path).readAsBytes();
    }
  }
}
