import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'package:kot_luy/pdf/desktop_pdf_file_handler.dart';
import 'package:kot_luy/pdf/pdf_download_result.dart';

export 'package:kot_luy/pdf/pdf_download_result.dart';

class PdfDownloader {
  static const MethodChannel _channel = MethodChannel('kot_luy/pdf_storage');

  @visibleForTesting
  static Future<PdfDownloadResult?> Function(Uint8List bytes, String filename)?
  saveOverride;

  @visibleForTesting
  static Future<bool> Function(String openIdentifier)? openOverride;

  /// Saves the given PDF bytes into the device's Downloads directory.
  /// Returns a [PdfDownloadResult] on success, or `null` if the platform
  /// does not support direct file downloads.
  static Future<PdfDownloadResult?> saveToDownloads({
    required Uint8List bytes,
    required String filename,
  }) async {
    if (saveOverride != null) {
      return saveOverride!(bytes, filename);
    }

    if (kIsWeb) {
      return null;
    }

    if (defaultTargetPlatform == TargetPlatform.android) {
      try {
        final res = await _channel.invokeMapMethod<String, dynamic>(
          'saveToDownloads',
          {'filename': filename, 'bytes': bytes},
        );
        if (res != null) {
          final path = res['path'] as String? ?? 'Downloads/$filename';
          final uri = res['uri'] as String? ?? '';
          return PdfDownloadResult(
            displayPath: path,
            openIdentifier: uri.isNotEmpty ? uri : path,
          );
        }
      } catch (e) {
        debugPrint('Android saveToDownloads error: $e');
        rethrow;
      }
      return null;
    }

    if (DesktopPdfFileHandler.supported) {
      try {
        return await DesktopPdfFileHandler.saveToDownloads(
          bytes: bytes,
          filename: filename,
        );
      } catch (e) {
        debugPrint('Desktop saveToDownloads error: $e');
        rethrow;
      }
    }

    return null;
  }

  /// Opens the PDF using the system viewer.
  static Future<bool> openFile(String openIdentifier) async {
    if (openOverride != null) {
      return openOverride!(openIdentifier);
    }

    if (kIsWeb) return false;

    if (defaultTargetPlatform == TargetPlatform.android) {
      try {
        final opened = await _channel.invokeMethod<bool>('openPdf', {
          'uri': openIdentifier,
        });
        return opened ?? false;
      } catch (e) {
        debugPrint('Android openPdf error: $e');
        return false;
      }
    }

    if (DesktopPdfFileHandler.supported) {
      try {
        return await DesktopPdfFileHandler.open(openIdentifier);
      } catch (e) {
        debugPrint('Desktop openFile error: $e');
        return false;
      }
    }

    return false;
  }
}
