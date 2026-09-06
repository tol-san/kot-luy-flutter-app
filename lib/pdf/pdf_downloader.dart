import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class PdfDownloadResult {
  const PdfDownloadResult({
    required this.displayPath,
    required this.openIdentifier,
  });

  final String displayPath;
  final String openIdentifier;
}

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

    if (Platform.isAndroid) {
      try {
        final res = await _channel.invokeMapMethod<String, dynamic>(
          'saveToDownloads',
          {
            'filename': filename,
            'bytes': bytes,
          },
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

    if (Platform.isWindows || Platform.isMacOS || Platform.isLinux) {
      try {
        String? downloadsPath;
        if (Platform.isWindows) {
          final userProfile = Platform.environment['USERPROFILE'];
          if (userProfile != null) {
            downloadsPath = '$userProfile\\Downloads';
          }
        } else {
          final home = Platform.environment['HOME'];
          if (home != null) {
            downloadsPath = '$home/Downloads';
          }
        }

        if (downloadsPath != null && Directory(downloadsPath).existsSync()) {
          final file = File('$downloadsPath${Platform.pathSeparator}$filename');
          await file.writeAsBytes(bytes);
          return PdfDownloadResult(
            displayPath: file.path,
            openIdentifier: file.path,
          );
        }
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

    if (Platform.isAndroid) {
      try {
        final opened = await _channel.invokeMethod<bool>(
          'openPdf',
          {'uri': openIdentifier},
        );
        return opened ?? false;
      } catch (e) {
        debugPrint('Android openPdf error: $e');
        return false;
      }
    }

    if (Platform.isWindows) {
      try {
        await Process.run('cmd', ['/c', 'start', '', openIdentifier]);
        return true;
      } catch (e) {
        debugPrint('Windows openFile error: $e');
        return false;
      }
    }

    if (Platform.isMacOS) {
      try {
        await Process.run('open', [openIdentifier]);
        return true;
      } catch (e) {
        debugPrint('macOS openFile error: $e');
        return false;
      }
    }

    if (Platform.isLinux) {
      try {
        await Process.run('xdg-open', [openIdentifier]);
        return true;
      } catch (e) {
        debugPrint('Linux openFile error: $e');
        return false;
      }
    }

    return false;
  }
}
