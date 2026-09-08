import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import 'package:kot_luy/backup/drive_backup.dart';
import 'package:kot_luy/theme.dart';

/// Card showing current Google Drive account connection status and connect/disconnect actions.
class DriveAccountCard extends StatelessWidget {
  const DriveAccountCard({
    super.key,
    required this.status,
    required this.actionInProgress,
    required this.onConnect,
    required this.onDisconnect,
  });

  final DriveBackupStatus status;
  final bool actionInProgress;
  final VoidCallback onConnect;
  final VoidCallback onDisconnect;

  @override
  Widget build(BuildContext context) {
    if (!status.isConnected) {
      return Container(
        padding: const EdgeInsets.all(18),
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
                SvgPicture.asset(
                  'assets/illustrations/google_drive.svg',
                  width: 22,
                  height: 20,
                ),
                const SizedBox(width: 10),
                const Text(
                  'គណនីផ្ទាល់ខ្លួនរបស់អ្នក',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: ink,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              'ទិន្នន័យបម្រុងទុកនឹងត្រូវរក្សាទុកក្នុង Google Drive ផ្ទាល់ខ្លួនរបស់អ្នក ',
              style: TextStyle(fontSize: 13, color: muted, height: 1.5),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: actionInProgress ? null : onConnect,
                icon: SvgPicture.asset(
                  'assets/illustrations/google_drive.svg',
                  width: 20,
                  height: 18,
                ),
                label: Text(
                  actionInProgress ? 'កំពុងភ្ជាប់...' : 'ភ្ជាប់ Google Drive',
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: line),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFFEDF1E3),
              borderRadius: BorderRadius.circular(12),
            ),
            child: SvgPicture.asset('assets/illustrations/google_drive.svg'),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text(
                      'បានភ្ជាប់រួចរាល់',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: green,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      width: 6,
                      height: 6,
                      decoration: const BoxDecoration(
                        color: green,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  status.email ?? '',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: ink,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: actionInProgress ? null : onDisconnect,
            child: const Text(
              'ផ្ដាច់',
              style: TextStyle(color: Color(0xFFAD5347), fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}
