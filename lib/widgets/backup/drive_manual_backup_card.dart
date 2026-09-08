import 'package:flutter/material.dart';

import '../../backup/drive_formatters.dart';
import '../../theme.dart';

/// Card providing a direct button to back up database to Google Drive immediately.
class DriveManualBackupCard extends StatelessWidget {
  const DriveManualBackupCard({
    super.key,
    required this.lastSuccess,
    required this.actionInProgress,
    required this.backingUp,
    required this.backupFailed,
    required this.backupFeedback,
    required this.onManualBackup,
  });

  final DateTime? lastSuccess;
  final bool actionInProgress;
  final bool backingUp;
  final bool backupFailed;
  final String? backupFeedback;
  final VoidCallback onManualBackup;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'បម្រុងទុកដោយផ្ទាល់',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: ink,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'ចុងក្រោយ: ${formatBackupDate(lastSuccess)}',
                      style: const TextStyle(fontSize: 12, color: muted),
                    ),
                  ],
                ),
              ),
              FilledButton.icon(
                onPressed: actionInProgress ? null : onManualBackup,
                style: FilledButton.styleFrom(
                  disabledBackgroundColor: backingUp ? green : null,
                  disabledForegroundColor: backingUp ? Colors.white : null,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  minimumSize: const Size(0, 42),
                ),
                icon: backingUp
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.backup_rounded, size: 18),
                label: Text(backingUp ? 'កំពុងបម្រុងទុក…' : 'បម្រុងទុកឥឡូវនេះ'),
              ),
            ],
          ),
          if (backupFeedback != null && backupFailed)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Semantics(
                liveRegion: true,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.error_outline,
                      size: 20,
                      color: Color(0xFFAD5347),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        backupFeedback!,
                        style: const TextStyle(
                          fontSize: 13,
                          color: Color(0xFFAD5347),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
