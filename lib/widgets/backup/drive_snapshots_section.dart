import 'package:flutter/material.dart';

import '../../backup/drive_backup.dart';
import '../../backup/drive_formatters.dart';
import '../../theme.dart';

/// Section showing list of remote Google Drive backups with refresh and restore actions.
class DriveSnapshotsSection extends StatelessWidget {
  const DriveSnapshotsSection({
    super.key,
    required this.remoteBackups,
    required this.actionInProgress,
    required this.restoringId,
    required this.onRefresh,
    required this.onRestore,
  });

  final List<DriveBackupItem> remoteBackups;
  final bool actionInProgress;
  final String? restoringId;
  final VoidCallback onRefresh;
  final ValueChanged<DriveBackupItem> onRestore;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                'ឯកសារបម្រុងទុកលើ Google Drive',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: ink,
                ),
              ),
            ),
            IconButton(
              tooltip: 'ទាញយកបញ្ជីឡើងវិញ',
              icon: const Icon(Icons.refresh_rounded, size: 20, color: muted),
              onPressed: actionInProgress ? null : onRefresh,
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (remoteBackups.isEmpty)
          Container(
            padding: const EdgeInsets.all(24),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: line),
            ),
            child: const Text(
              'មិនទាន់មានឯកសារបម្រុងទុកនៅឡើយទេ\nចុច «បម្រុងទុកឥឡូវនេះ» ដើម្បីបង្កើត',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: muted, height: 1.5),
            ),
          )
        else
          ...remoteBackups.map((item) => _snapshotTile(item)),
      ],
    );
  }

  Widget _snapshotTile(DriveBackupItem item) => Container(
    margin: const EdgeInsets.only(bottom: 10),
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: line),
    ),
    child: Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: const Color(0xFFEDF1E3),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(Icons.description_outlined, color: green, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                formatBackupDate(item.createdTime),
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: ink,
                ),
              ),
              const SizedBox(height: 2),
              Row(
                children: [
                  Text(
                    formatBackupBytes(item.size),
                    style: const TextStyle(fontSize: 12, color: muted),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 1,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F3EA),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text(
                      'Read-only',
                      style: TextStyle(fontSize: 10, color: muted),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        OutlinedButton.icon(
          onPressed: actionInProgress ? null : () => onRestore(item),
          style: OutlinedButton.styleFrom(
            foregroundColor: green,
            disabledForegroundColor: restoringId == item.id ? green : muted,
            side: BorderSide(
              color: actionInProgress && restoringId != item.id ? line : green,
            ),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            minimumSize: const Size(0, 34),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          icon: restoringId == item.id
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: green,
                  ),
                )
              : null,
          label: Text(
            restoringId == item.id ? 'កំពុងស្ដារ…' : 'ស្ដារ',
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
          ),
        ),
      ],
    ),
  );
}
