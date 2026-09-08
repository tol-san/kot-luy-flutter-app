import 'dart:io';
import 'dart:typed_data';

import 'package:kot_luy/pdf/pdf_download_result.dart';

/// Handles desktop file-system operations for exported PDF files.
class DesktopPdfFileHandler {
  const DesktopPdfFileHandler._();

  static bool get supported =>
      Platform.isWindows || Platform.isMacOS || Platform.isLinux;

  static Future<PdfDownloadResult?> saveToDownloads({
    required Uint8List bytes,
    required String filename,
  }) async {
    final downloadsPath = _downloadsPath();
    if (downloadsPath == null || !Directory(downloadsPath).existsSync()) {
      return null;
    }
    final file = File('$downloadsPath${Platform.pathSeparator}$filename');
    await file.writeAsBytes(bytes);
    return PdfDownloadResult(displayPath: file.path, openIdentifier: file.path);
  }

  static Future<bool> open(String openIdentifier) async {
    if (Platform.isWindows) {
      await Process.run('cmd', ['/c', 'start', '', openIdentifier]);
      return true;
    }
    if (Platform.isMacOS) {
      await Process.run('open', [openIdentifier]);
      return true;
    }
    if (Platform.isLinux) {
      await Process.run('xdg-open', [openIdentifier]);
      return true;
    }
    return false;
  }

  static String? _downloadsPath() {
    if (Platform.isWindows) {
      final userProfile = Platform.environment['USERPROFILE'];
      return userProfile == null ? null : '$userProfile\\Downloads';
    }
    final homeDirectory = Platform.environment['HOME'];
    return homeDirectory == null ? null : '$homeDirectory/Downloads';
  }
}
