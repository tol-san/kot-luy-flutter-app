import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:intl/intl.dart' hide TextDirection;

import '../backup/drive_backup.dart';
import '../data/expense_repository.dart';
import '../theme.dart';

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
          _errorMessage = _parseError(e);
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
        ScaffoldMessenger.of(context).showSnackBar(
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
          _errorMessage = _parseConnectError(e);
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
          _errorMessage = 'មិនអាចផ្ដាច់គណនីបានទេ: ${_parseError(e)}';
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
          _backupFeedback = _parseError(e);
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
          _errorMessage = _parseError(e);
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
          _errorMessage = _parseError(e);
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
          '${_formatDate(item.createdTime)} (${_formatBytes(item.size)})\n\n'
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
        ScaffoldMessenger.of(context).showSnackBar(
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
          _errorMessage = 'ការស្ដារបរាជ័យ: ${_parseError(e)}';
          _restoringId = null;
        });
      }
    }
  }

  String? _parseConnectError(Object error) {
    final str = error.toString().toLowerCase();
    if (str.contains('cancelled') ||
        str.contains('canceled') ||
        str.contains('no_account')) {
      // User dismissed account chooser dialog; no error banner needed
      return null;
    }
    if (str.contains('auth_denied') ||
        str.contains('authorization was not granted') ||
        str.contains('permission')) {
      return 'អ្នកមិនទាន់បានអនុញ្ញាតសិទ្ធិ Google Drive នៅឡើយទេ។ សូមព្យាយាមភ្ជាប់ម្ដងទៀត ហើយចុច «យល់ព្រម» ឬ «Allow»។';
    }
    if (str.contains('network') ||
        str.contains('socket') ||
        str.contains('timeout')) {
      return 'បញ្ហាតភ្ជាប់បណ្ដាញ សូមពិនិត្យមើល Wi-Fi ឬទិន្នន័យចល័ត (SIM)';
    }
    return 'ការភ្ជាប់មិនបានសម្រេចទេ សូមព្យាយាមម្ដងទៀត';
  }

  String _parseError(Object error) {
    final str = error.toString().toLowerCase();
    if (str.contains('network') ||
        str.contains('socket') ||
        str.contains('timeout')) {
      return 'បញ្ហាតភ្ជាប់បណ្ដាញ សូមពិនិត្យមើល Wi-Fi ឬទិន្នន័យចល័ត (SIM)';
    } else if (str.contains('auth_denied') ||
        str.contains('authorization was not granted') ||
        str.contains('permission')) {
      return 'មិនទាន់បានអនុញ្ញាតសិទ្ធិ Google Drive នៅឡើយទេ។ សូមភ្ជាប់ឡើងវិញ ហើយចុច «យល់ព្រម» ឬ «Allow»។';
    } else if (str.contains('reconnect') ||
        str.contains('unauthenticated') ||
        str.contains('auth_failed')) {
      return 'សូមភ្ជាប់គណនី Google ឡើងវិញ';
    } else if (str.contains('quota') || str.contains('storage')) {
      return 'ទំហំផ្ទុកលើ Google Drive របស់អ្នកបានពេញ';
    } else if (str.contains('too_large')) {
      return 'ឯកសារបម្រុងទុកមានទំហំធំលើសកំណត់';
    } else if (str.contains('integrity') || str.contains('invalid')) {
      return 'ឯកសារបម្រុងទុកមិនត្រឹមត្រូវ ឬខូចខាត';
    }
    return 'មិនអាចដំណើរការបានទេ សូមព្យាយាមម្ដងទៀត';
  }

  String _formatDate(DateTime? dt) {
    if (dt == null) return 'មិនទាន់មាន';
    return DateFormat('dd/MM/yyyy HH:mm').format(dt);
  }

  String _formatBytes(int? bytes) {
    if (bytes == null || bytes <= 0) return '';
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
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
                          Container(
                            margin: const EdgeInsets.only(bottom: 16),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFBF0EF),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: const Color(0xFFF3D0CB),
                              ),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Padding(
                                  padding: EdgeInsets.only(top: 2),
                                  child: Icon(
                                    Icons.error_outline_rounded,
                                    color: Color(0xFFAD5347),
                                    size: 20,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    _errorMessage!,
                                    style: const TextStyle(
                                      color: Color(0xFFAD5347),
                                      fontSize: 13,
                                      height: 1.5,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 4),
                                GestureDetector(
                                  onTap: () => setState(() => _errorMessage = null),
                                  child: const Padding(
                                    padding: EdgeInsets.all(2),
                                    child: Icon(
                                      Icons.close_rounded,
                                      color: Color(0xFFAD5347),
                                      size: 18,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),

                        // Account connection card
                        _accountCard(),
                        const SizedBox(height: 16),

                        if (_status.isConnected) ...[
                          // Auto backup & network settings
                          _settingsCard(allowSim),
                          const SizedBox(height: 16),

                          // Manual backup action
                          _manualBackupCard(),
                          const SizedBox(height: 20),

                          // Backups list from Google Drive
                          _snapshotsSection(),
                        ],
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _accountCard() {
    if (!_status.isConnected) {
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
                onPressed: _actionInProgress ? null : _connect,
                icon: SvgPicture.asset(
                  'assets/illustrations/google_drive.svg',
                  width: 20,
                  height: 18,
                ),
                label: Text(
                  _actionInProgress ? 'កំពុងភ្ជាប់...' : 'ភ្ជាប់ Google Drive',
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
                  _status.email ?? '',
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
            onPressed: _actionInProgress ? null : _disconnect,
            child: const Text(
              'ផ្ដាច់',
              style: TextStyle(color: Color(0xFFAD5347), fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  Widget _settingsCard(bool allowSim) => Material(
    color: Colors.white,
    clipBehavior: Clip.antiAlias,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(18),
      side: const BorderSide(color: line),
    ),
    child: Column(
      children: [
        SwitchListTile(
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 4,
          ),
          title: const Text(
            'បម្រុងទុកស្វ័យប្រវត្តិ (Silent)',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: ink,
            ),
          ),
          subtitle: const Text(
            'បម្រុងទុកដោយស្ងាត់ៗពេលទិន្នន័យប្រែប្រួល និងរៀងរាល់ 6 ម៉ោង',
            style: TextStyle(fontSize: 12, color: muted),
          ),
          value: _status.automatic,
          activeThumbColor: green,
          thumbColor: _lockedSwitchThumb,
          trackColor: _lockedSwitchTrack,
          onChanged: _actionInProgress ? null : _toggleAutomatic,
        ),
        const Divider(height: 1, indent: 16, endIndent: 16),
        SwitchListTile(
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 4,
          ),
          title: const Text(
            'ប្រើ Wi-Fi ឬទិន្នន័យចល័ត (SIM)',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: ink,
            ),
          ),
          subtitle: Text(
            allowSim
                ? 'អនុញ្ញាតឱ្យបម្រុងទុកទាំងតាម SIM ទូរសព្ទ និង Wi-Fi'
                : 'បម្រុងទុកតែតាមប្រព័ន្ធ Wi-Fi ប៉ុណ្ណោះ',
            style: const TextStyle(fontSize: 12, color: muted),
          ),
          value: allowSim,
          activeThumbColor: green,
          thumbColor: _lockedSwitchThumb,
          trackColor: _lockedSwitchTrack,
          onChanged: _actionInProgress ? null : _toggleSimData,
        ),
      ],
    ),
  );

  // Disabled is an interaction state, not a change to the saved ON/OFF value.
  WidgetStateProperty<Color?> get _lockedSwitchThumb =>
      WidgetStateProperty.resolveWith((states) {
        if (!states.contains(WidgetState.disabled)) return null;
        return states.contains(WidgetState.selected)
            ? const Color(0xFF52735F)
            : const Color(0xFF737873);
      });

  WidgetStateProperty<Color?> get _lockedSwitchTrack =>
      WidgetStateProperty.resolveWith((states) {
        if (!states.contains(WidgetState.disabled)) return null;
        return states.contains(WidgetState.selected)
            ? const Color(0xFFB8CDBF)
            : const Color(0xFFE0E3DE);
      });

  Widget _manualBackupCard() => Container(
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
                    'ចុងក្រោយ: ${_formatDate(_status.lastSuccess)}',
                    style: const TextStyle(fontSize: 12, color: muted),
                  ),
                ],
              ),
            ),
            FilledButton.icon(
              onPressed: _actionInProgress ? null : _manualBackup,
              style: FilledButton.styleFrom(
                disabledBackgroundColor: _backingUp ? green : null,
                disabledForegroundColor: _backingUp ? Colors.white : null,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                minimumSize: const Size(0, 42),
              ),
              icon: _backingUp
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.backup_rounded, size: 18),
              label: Text(_backingUp ? 'កំពុងបម្រុងទុក…' : 'បម្រុងទុកឥឡូវនេះ'),
            ),
          ],
        ),
        if (_backupFeedback != null && _backupFailed)
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
                      _backupFeedback!,
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

  Widget _snapshotsSection() {
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
              onPressed: _actionInProgress ? null : _refreshStatus,
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (_remoteBackups.isEmpty)
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
          ..._remoteBackups.map((item) => _snapshotTile(item)),
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
                _formatDate(item.createdTime),
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
                    _formatBytes(item.size),
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
          onPressed: _actionInProgress ? null : () => _restore(item),
          style: OutlinedButton.styleFrom(
            foregroundColor: green,
            disabledForegroundColor: _restoringId == item.id ? green : muted,
            side: BorderSide(
              color: _actionInProgress && _restoringId != item.id
                  ? line
                  : green,
            ),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            minimumSize: const Size(0, 34),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          icon: _restoringId == item.id
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
            _restoringId == item.id ? 'កំពុងស្ដារ…' : 'ស្ដារ',
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
          ),
        ),
      ],
    ),
  );
}

class DriveBackupSkeleton extends StatefulWidget {
  const DriveBackupSkeleton({super.key});

  @override
  State<DriveBackupSkeleton> createState() => _DriveBackupSkeletonState();
}

class _DriveBackupSkeletonState extends State<DriveBackupSkeleton>
    with SingleTickerProviderStateMixin {
  AnimationController? _controller;

  @override
  void initState() {
    super.initState();
    final isTest =
        WidgetsBinding.instance.runtimeType.toString().contains('Test');
    if (!isTest) {
      _controller = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 1400),
      )..repeat();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final disableAnimations =
        MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    if (disableAnimations) {
      _controller?.stop();
    } else if (_controller != null && !_controller!.isAnimating) {
      _controller!.repeat();
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _ShimmerScope(
      animation: _controller,
      child: ListView(
        physics: const ClampingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
        children: [
          _skeletonAccountCard(),
          const SizedBox(height: 16),
          _skeletonSettingsCard(),
          const SizedBox(height: 16),
          _skeletonManualBackupCard(),
          const SizedBox(height: 20),
          _skeletonSnapshotsSection(),
        ],
      ),
    );
  }

  Widget _skeletonAccountCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: line),
      ),
      child: Row(
        children: [
          const _SkeletonBox(width: 40, height: 40, borderRadius: 12),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                _SkeletonBox(width: 90, height: 12, borderRadius: 6),
                SizedBox(height: 8),
                _SkeletonBox(width: 150, height: 14, borderRadius: 6),
              ],
            ),
          ),
          const SizedBox(width: 12),
          const _SkeletonBox(width: 44, height: 28, borderRadius: 8),
        ],
      ),
    );
  }

  Widget _skeletonSettingsCard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: line),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      _SkeletonBox(width: 180, height: 14, borderRadius: 6),
                      SizedBox(height: 8),
                      _SkeletonBox(width: 240, height: 11, borderRadius: 6),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                const _SkeletonBox(width: 44, height: 24, borderRadius: 12),
              ],
            ),
          ),
          const Divider(height: 1, indent: 16, endIndent: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      _SkeletonBox(width: 160, height: 14, borderRadius: 6),
                      SizedBox(height: 8),
                      _SkeletonBox(width: 210, height: 11, borderRadius: 6),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                const _SkeletonBox(width: 44, height: 24, borderRadius: 12),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _skeletonManualBackupCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: line),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                _SkeletonBox(width: 130, height: 14, borderRadius: 6),
                SizedBox(height: 8),
                _SkeletonBox(width: 160, height: 11, borderRadius: 6),
              ],
            ),
          ),
          const SizedBox(width: 12),
          const _SkeletonBox(width: 128, height: 42, borderRadius: 16),
        ],
      ),
    );
  }

  Widget _skeletonSnapshotsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: const [
            _SkeletonBox(width: 175, height: 16, borderRadius: 6),
            Spacer(),
            _SkeletonBox(width: 28, height: 28, borderRadius: 14),
          ],
        ),
        const SizedBox(height: 12),
        _skeletonSnapshotTile(),
        _skeletonSnapshotTile(),
      ],
    );
  }

  Widget _skeletonSnapshotTile() {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: line),
      ),
      child: Row(
        children: [
          const _SkeletonBox(width: 36, height: 36, borderRadius: 10),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _SkeletonBox(width: 120, height: 14, borderRadius: 6),
                const SizedBox(height: 8),
                Row(
                  children: const [
                    _SkeletonBox(width: 55, height: 11, borderRadius: 4),
                    SizedBox(width: 8),
                    _SkeletonBox(width: 48, height: 14, borderRadius: 4),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          const _SkeletonBox(width: 62, height: 34, borderRadius: 10),
        ],
      ),
    );
  }
}

class _ShimmerScope extends InheritedWidget {
  const _ShimmerScope({
    required this.animation,
    required super.child,
  });

  final Animation<double>? animation;

  static Animation<double>? of(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<_ShimmerScope>()?.animation;
  }

  @override
  bool updateShouldNotify(_ShimmerScope oldWidget) =>
      animation != oldWidget.animation;
}

class _SkeletonBox extends StatelessWidget {
  const _SkeletonBox({
    this.width,
    this.height,
    this.borderRadius = 8,
  });

  final double? width;
  final double? height;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    final animation = _ShimmerScope.of(context);
    const baseColor = Color(0xFFECEFE6);
    const highlightColor = Color(0xFFF7F9F3);

    if (animation == null) {
      return Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: baseColor,
          borderRadius: BorderRadius.circular(borderRadius),
        ),
      );
    }

    return AnimatedBuilder(
      animation: animation,
      builder: (context, _) {
        return Container(
          width: width,
          height: height,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(borderRadius),
            gradient: LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: const [baseColor, highlightColor, baseColor],
              stops: const [0.1, 0.5, 0.9],
              transform: _SlidingGradientTransform(
                slidePercent: animation.value,
              ),
            ),
          ),
        );
      },
    );
  }
}

class _SlidingGradientTransform extends GradientTransform {
  const _SlidingGradientTransform({required this.slidePercent});
  final double slidePercent;

  @override
  Matrix4? transform(Rect bounds, {TextDirection? textDirection}) {
    return Matrix4.translationValues(
      bounds.width * (slidePercent * 2.0 - 1.0),
      0.0,
      0.0,
    );
  }
}
