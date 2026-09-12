import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import 'package:kot_luy/backup/drive_backup.dart';
import 'package:kot_luy/backup/drive_error_parser.dart';
import 'package:kot_luy/backup/drive_formatters.dart';
import 'package:kot_luy/data/expense_repository.dart';
import 'package:kot_luy/globals.dart';
import 'package:kot_luy/theme.dart';
import 'package:kot_luy/widgets/backup/backup_error_banner.dart';
import 'package:kot_luy/widgets/backup/drive_account_card.dart';
import 'package:kot_luy/widgets/backup/drive_backup_skeleton.dart';
import 'package:kot_luy/widgets/backup/drive_manual_backup_card.dart';
import 'package:kot_luy/widgets/backup/drive_settings_card.dart';
import 'package:kot_luy/widgets/backup/drive_snapshots_section.dart';

export '../widgets/backup/drive_backup_skeleton.dart' show DriveBackupSkeleton;

class DriveBackupSheet extends StatefulWidget {
  const DriveBackupSheet({
    super.key,
    required this.repository,
    this.onDataRestored,
  });

  final ExpenseRepository repository;
  final VoidCallback? onDataRestored;

  static Future<void> show(
    BuildContext context,
    ExpenseRepository repository, {
    VoidCallback? onDataRestored,
  }) => showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => DriveBackupSheet(
      repository: repository,
      onDataRestored: onDataRestored,
    ),
  );

  @override
  State<DriveBackupSheet> createState() => _DriveBackupSheetState();
}

class _DriveBackupSheetState extends State<DriveBackupSheet> {
  final _drive = DriveBackup();
  DriveBackupStatus _status = const DriveBackupStatus();
  List<DriveBackupItem> _remoteBackups = [];
  bool _loading = true;
  bool _actionInProgress = false;
  bool _backingUp = false;
  String? _backupFeedback;
  bool _backupFailed = false;
  String? _restoringId;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _refreshStatus();
  }

  Future<void> _refreshStatus() async {
    setState(() {
      _loading = true;
      _errorMessage = null;
    });
    try {
      final status = await _drive.getStatus();
      List<DriveBackupItem> list = [];
      if (status.isConnected) {
        try {
          list = await _drive.list();
        } catch (_) {}
      }
      if (mounted) {
        setState(() {
          _status = status;
          _remoteBackups = list;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _errorMessage = parseDriveError(e);
        });
      }
    }
  }

  Future<void> _connect() async {
    setState(() {
      _actionInProgress = true;
      _errorMessage = null;
    });
    try {
      final status = await _drive.connect();
      List<DriveBackupItem> list = [];
      try {
        list = await _drive.list();
      } catch (_) {}
      if (mounted) {
        setState(() {
          _status = status;
          _remoteBackups = list;
          _actionInProgress = false;
        });
        rootMessengerKey.currentState?.showSnackBar(
          const SnackBar(
            content: Text('បានភ្ជាប់ Google Drive ជោគជ័យ'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _actionInProgress = false;
          _errorMessage = parseDriveConnectError(e);
        });
      }
    }
  }

  Future<void> _disconnect() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('ផ្ដាច់គណនី Google?'),
        content: const Text(
          'ការបម្រុងទុកស្វ័យប្រវត្តិនឹងត្រូវផ្អាក។ ទិន្នន័យដែលមានស្រាប់លើ Google Drive នឹងមិនបាត់បង់ឡើយ។',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('បោះបង់'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              'ផ្ដាច់',
              style: TextStyle(color: Color(0xFFAD5347)),
            ),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _actionInProgress = true);
    try {
      final status = await _drive.disconnect();
      if (mounted) {
        setState(() {
          _status = status;
          _remoteBackups = [];
          _actionInProgress = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _actionInProgress = false;
          _errorMessage = 'មិនអាចផ្ដាច់គណនីបានទេ: ${parseDriveError(e)}';
        });
      }
    }
  }

  Future<void> _manualBackup() async {
    setState(() {
      _actionInProgress = true;
      _backingUp = true;
      _backupFeedback = null;
      _backupFailed = false;
      _errorMessage = null;
    });
    try {
      final status = await _drive.backup();
      if (!mounted) return;
      List<DriveBackupItem>? list;
      try {
        list = await _drive.list();
      } catch (_) {}
      if (mounted) {
        final messenger = ScaffoldMessenger.of(context);
        setState(() {
          _status = status;
          if (list != null) _remoteBackups = list;
          _actionInProgress = false;
          _backingUp = false;
        });
        Navigator.pop(context);
        messenger.showSnackBar(
          const SnackBar(
            content: Text('បានបម្រុងទុកទៅ Google Drive ដោយជោគជ័យ!'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _actionInProgress = false;
          _backupFailed = true;
          _backupFeedback = parseDriveError(e);
          _backingUp = false;
        });
      }
    }
  }

  Future<void> _toggleAutomatic(bool value) async {
    setState(() => _actionInProgress = true);
    try {
      final status = await _drive.configure(
        automatic: value,
        wifiOnly: _status.wifiOnly,
      );
      if (mounted) {
        setState(() {
          _status = status;
          _actionInProgress = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _actionInProgress = false;
          _errorMessage = parseDriveError(e);
        });
      }
    }
  }

  Future<void> _toggleSimData(bool allowSimAndWifi) async {
    // allowSimAndWifi == true -> wifiOnly = false (uses SIM or Wi-Fi)
    // allowSimAndWifi == false -> wifiOnly = true (only Wi-Fi)
    setState(() => _actionInProgress = true);
    try {
      final status = await _drive.configure(
        automatic: _status.automatic,
        wifiOnly: !allowSimAndWifi,
      );
      if (mounted) {
        setState(() {
          _status = status;
          _actionInProgress = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _actionInProgress = false;
          _errorMessage = parseDriveError(e);
        });
      }
    }
  }

  Future<void> _restore(DriveBackupItem item) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('ស្ដារទិន្នន័យឡើងវិញ?'),
        content: Text(
          'ទិន្នន័យបច្ចុប្បន្ននឹងត្រូវបានជំនួសដោយកំណត់ត្រាពី:\n'
          '${formatBackupDate(item.createdTime)} (${formatBackupBytes(item.size)})\n\n'
          'ប្រព័ន្ធនឹងរក្សាទុកច្បាប់ចម្លងសុវត្ថិភាពនៃទិន្នន័យបច្ចុប្បន្នដោយស្វ័យប្រវត្តិ។',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('បោះបង់'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('ស្ដារឡើងវិញ'),
          ),
        ],
      ),
    );

    if (confirm != true || !mounted) return;

    setState(() {
      _actionInProgress = true;
      _restoringId = item.id;
      _errorMessage = null;
    });

    try {
      await _drive.restore(item.id, widget.repository.database);
      widget.onDataRestored?.call();
      if (mounted) {
        setState(() {
          _actionInProgress = false;
          _restoringId = null;
        });
        Navigator.pop(context);
        rootMessengerKey.currentState?.showSnackBar(
          const SnackBar(
            content: Text('បានស្ដារទិន្នន័យឡើងវិញដោយជោគជ័យ!'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _actionInProgress = false;
          _errorMessage = 'ការស្ដារបរាជ័យ: ${parseDriveError(e)}';
          _restoringId = null;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    final allowSim = !_status.wifiOnly;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.88,
      ),
      padding: EdgeInsets.only(bottom: bottomInset),
      decoration: const BoxDecoration(
        color: paper,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Drag handle
            Center(
              child: Container(
                margin: const EdgeInsets.only(top: 12, bottom: 8),
                width: 44,
                height: 4,
                decoration: BoxDecoration(
                  color: line,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 16, 12),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    padding: const EdgeInsets.all(9),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEDF1E3),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: SvgPicture.asset(
                      'assets/illustrations/google_drive.svg',
                    ),
                  ),
                  const SizedBox(width: 14),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'បម្រុងទុកលើ Google Drive',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: ink,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'រក្សាទុកចំណាយរបស់អ្នកដោយសុវត្ថិភាព',
                          style: TextStyle(fontSize: 12, color: muted),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: muted),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            // Body
            Expanded(
              child: _loading
                  ? const DriveBackupSkeleton()
                  : ListView(
                      padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
                      children: [
                        if (_errorMessage != null)
                          BackupErrorBanner(
                            message: _errorMessage!,
                            onDismiss: () =>
                                setState(() => _errorMessage = null),
                          ),

                        // Account connection card
                        DriveAccountCard(
                          status: _status,
                          actionInProgress: _actionInProgress,
                          onConnect: _connect,
                          onDisconnect: _disconnect,
                        ),
                        const SizedBox(height: 16),

                        if (_status.isConnected) ...[
                          // Auto backup & network settings
                          DriveSettingsCard(
                            automatic: _status.automatic,
                            allowSim: allowSim,
                            actionInProgress: _actionInProgress,
                            onToggleAutomatic: _toggleAutomatic,
                            onToggleSimData: _toggleSimData,
                          ),
                          const SizedBox(height: 16),

                          // Manual backup action
                          DriveManualBackupCard(
                            lastSuccess: _status.lastSuccess,
                            actionInProgress: _actionInProgress,
                            backingUp: _backingUp,
                            backupFailed: _backupFailed,
                            backupFeedback: _backupFeedback,
                            onManualBackup: _manualBackup,
                          ),
                          const SizedBox(height: 20),

                          // Backups list from Google Drive
                          DriveSnapshotsSection(
                            remoteBackups: _remoteBackups,
                            actionInProgress: _actionInProgress,
                            restoringId: _restoringId,
                            onRefresh: _refreshStatus,
                            onRestore: _restore,
                          ),
                        ],
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
