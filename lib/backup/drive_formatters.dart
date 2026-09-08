import 'package:intl/intl.dart';

/// Formats a timestamp for Google Drive backup views (dd/MM/yyyy HH:mm).
String formatBackupDate(DateTime? dt) {
  if (dt == null) return 'មិនទាន់មាន';
  return DateFormat('dd/MM/yyyy HH:mm').format(dt);
}

/// Formats a byte size into human-readable B, KB, or MB string.
String formatBackupBytes(int? bytes) {
  if (bytes == null || bytes <= 0) return '';
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
  return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
}
