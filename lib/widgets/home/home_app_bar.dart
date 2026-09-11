import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import 'package:kot_luy/theme.dart';

class HomeAppBar extends StatelessWidget {
  const HomeAppBar({
    super.key,
    required this.onPdfExport,
    required this.onDriveBackup,
    this.onReminderSettings,
  });

  final VoidCallback onPdfExport;
  final VoidCallback onDriveBackup;
  final VoidCallback? onReminderSettings;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Image.asset(
        'assets/logo.png',
        width: 93,
        height: 36,
        fit: BoxFit.contain,
        semanticLabel: 'កត់លុយ',
      ),
      const Spacer(),
      if (onReminderSettings != null) ...[
        IconButton(
          key: const Key('reminderSettingsButton'),
          tooltip: 'ការរំលឹក',
          onPressed: onReminderSettings,
          icon: Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: const Color(0xFFEDF1E3),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.notifications_none_rounded,
              color: green,
              size: 20,
            ),
          ),
        ),
        const SizedBox(width: 6),
      ],
      IconButton(
        key: const Key('pdfExportHeaderButton'),
        tooltip: 'ទាញយករបាយការណ៍ PDF',
        onPressed: onPdfExport,
        icon: Container(
          padding: const EdgeInsets.all(7),
          decoration: BoxDecoration(
            color: const Color(0xFFEDF1E3),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(
            Icons.picture_as_pdf_outlined,
            color: green,
            size: 20,
          ),
        ),
      ),
      const SizedBox(width: 6),
      IconButton(
        tooltip: 'បម្រុងទុកទិន្នន័យ (Google Drive)',
        onPressed: onDriveBackup,
        icon: Container(
          padding: const EdgeInsets.all(7),
          decoration: BoxDecoration(
            color: const Color(0xFFEDF1E3),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(Icons.cloud_sync_outlined, color: green, size: 20),
        ),
      ),
    ],
  );
}

class HomeCompanion extends StatelessWidget {
  const HomeCompanion({super.key, required this.hasExpenses});

  final bool hasExpenses;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.fromLTRB(18, 8, 6, 8),
    decoration: BoxDecoration(
      color: const Color(0xFFEDF1E3),
      borderRadius: BorderRadius.circular(22),
    ),
    child: Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'ហេ៎! ធ្វើបានល្អហើយ 🌿',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 5),
              Text(
                hasExpenses
                    ? 'រាល់ការកត់ត្រា ជួយឱ្យអ្នក\nស្គាល់ទម្លាប់ចំណាយខ្លួនឯង។'
                    : 'ចាប់ផ្ដើមពីចំណាយដំបូង\nខ្ញុំនៅទីនេះ ជួយអ្នកកត់ត្រា។',
                style: const TextStyle(
                  color: Color(0xFF505F46),
                  fontSize: 11,
                  height: 1.8,
                ),
              ),
            ],
          ),
        ),
        SvgPicture.asset(
          'assets/illustrations/wallet.svg',
          width: 96,
          height: 90,
          semanticsLabel: 'មិត្តកាបូបលុយញញឹម',
        ),
      ],
    ),
  );
}

class HomeNavigationItem extends StatelessWidget {
  const HomeNavigationItem({
    super.key,
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(14),
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 5, horizontal: 2),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: selected ? green : muted, size: 22),
          const SizedBox(height: 5),
          Text(
            label,
            style: TextStyle(
              fontSize: 9,
              color: selected ? green : muted,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
            ),
          ),
        ],
      ),
    ),
  );
}
