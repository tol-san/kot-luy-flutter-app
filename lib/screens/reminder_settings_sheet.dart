import 'package:flutter/material.dart';

import 'package:kot_luy/globals.dart';
import 'package:kot_luy/services/reminder_service.dart';
import 'package:kot_luy/theme.dart';

class ReminderSettingsSheet extends StatefulWidget {
  const ReminderSettingsSheet({super.key, required this.reminderService});

  final ReminderService reminderService;

  static Future<void> show(
    BuildContext context, {
    required ReminderService reminderService,
  }) => showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    backgroundColor: paper,
    constraints: const BoxConstraints(maxWidth: 560),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: (_) => ReminderSettingsSheet(reminderService: reminderService),
  );

  @override
  State<ReminderSettingsSheet> createState() => _ReminderSettingsSheetState();
}

class _ReminderSettingsSheetState extends State<ReminderSettingsSheet>
    with WidgetsBindingObserver {
  ReminderSettings _settings = const ReminderSettings.defaults();
  bool _loading = true;
  ReminderKind? _saving;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _load();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _load();
    }
  }

  Future<void> _load() async {
    final settings = await widget.reminderService.loadSettings();
    if (!mounted) return;
    setState(() {
      _settings = settings;
      _loading = false;
    });
  }

  Future<void> _toggle(ReminderKind kind, bool enabled) async {
    if (_saving != null) return;
    setState(() => _saving = kind);
    final succeeded = await widget.reminderService.setEnabled(kind, enabled);
    if (!mounted) return;
    if (succeeded) {
      setState(() {
        _settings = _settings.copyWith(kind: kind, enabled: enabled);
        _saving = null;
      });
      return;
    }
    setState(() => _saving = null);
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('មិនអាចបើកការរំលឹកបានទេ'),
        content: const Text(
          'ការជូនដំណឹងត្រូវបានបិទក្នុងទូរស័ព្ទរបស់អ្នក។ សូមបើកការកំណត់ទូរស័ព្ទ ហើយចុច «អនុញ្ញាតការជូនដំណឹង»។',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('បោះបង់'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              widget.reminderService.openSystemNotificationSettings();
            },
            child: const Text('បើកការកំណត់'),
          ),
        ],
      ),
    );
  }

  Future<void> _pickTime(ReminderKind kind) async {
    if (_saving != null || !_settings.enabledFor(kind)) return;
    final selected = await showTimePicker(
      context: context,
      initialTime: _settings.timeFor(kind),
      helpText: 'ជ្រើសម៉ោងរំលឹក',
      cancelText: 'បោះបង់',
      confirmText: 'យល់ព្រម',
    );
    if (selected == null || selected == _settings.timeFor(kind) || !mounted) {
      return;
    }
    setState(() => _saving = kind);
    try {
      await widget.reminderService.updateTime(kind, selected);
      if (!mounted) return;
      setState(() {
        _settings = _settings.copyWith(kind: kind, time: selected);
        _saving = null;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _saving = null);
      rootMessengerKey.currentState?.showSnackBar(
        const SnackBar(
          content: Text('មិនអាចប្ដូរម៉ោងរំលឹកបានទេ។ សូមសាកល្បងម្ដងទៀត។'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
    child: _loading
        ? const SizedBox(
            height: 260,
            child: Center(child: CircularProgressIndicator()),
          )
        : SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.notifications_none_rounded, color: green),
                    SizedBox(width: 10),
                    Text(
                      'ការរំលឹក',
                      style: TextStyle(
                        fontSize: 21,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                const Text(
                  'ជ្រើសការរំលឹកដែលមានប្រយោជន៍សម្រាប់អ្នក។',
                  style: TextStyle(color: muted, fontSize: 12, height: 1.6),
                ),
                const SizedBox(height: 18),
                _ReminderCard(
                  kind: ReminderKind.daily,
                  title: 'រំលឹកកត់ចំណាយប្រចាំថ្ងៃ',
                  subtitle: 'រំលឹកឲ្យអ្នកកត់ចំណាយម្តងក្នុងមួយថ្ងៃ',
                  settings: _settings,
                  saving: _saving,
                  onToggle: _toggle,
                  onPickTime: _pickTime,
                ),
                const SizedBox(height: 12),
                _ReminderCard(
                  kind: ReminderKind.weekly,
                  title: 'សង្ខេបចំណាយប្រចាំសប្ដាហ៍',
                  subtitle: 'ផ្ញើរៀងរាល់ថ្ងៃអាទិត្យ',
                  settings: _settings,
                  saving: _saving,
                  onToggle: _toggle,
                  onPickTime: _pickTime,
                ),
                const SizedBox(height: 12),
                _ReminderCard(
                  kind: ReminderKind.monthly,
                  title: 'សង្ខេបចំណាយប្រចាំខែ',
                  subtitle: 'ផ្ញើនៅថ្ងៃចុងក្រោយនៃខែ',
                  settings: _settings,
                  saving: _saving,
                  onToggle: _toggle,
                  onPickTime: _pickTime,
                ),
              ],
            ),
          ),
  );
}

class _ReminderCard extends StatelessWidget {
  const _ReminderCard({
    required this.kind,
    required this.title,
    required this.subtitle,
    required this.settings,
    required this.saving,
    required this.onToggle,
    required this.onPickTime,
  });

  final ReminderKind kind;
  final String title;
  final String subtitle;
  final ReminderSettings settings;
  final ReminderKind? saving;
  final void Function(ReminderKind, bool) onToggle;
  final void Function(ReminderKind) onPickTime;

  @override
  Widget build(BuildContext context) {
    final enabled = settings.enabledFor(kind);
    final time = settings.timeFor(kind);
    final timeLabel = MaterialLocalizations.of(context).formatTimeOfDay(time);
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: line),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        clipBehavior: Clip.antiAlias,
        child: Column(
          children: [
            SwitchListTile(
              key: Key('${kind.name}ReminderSwitch'),
              value: enabled,
              onChanged: saving == null
                  ? (value) => onToggle(kind, value)
                  : null,
              activeThumbColor: Colors.white,
              activeTrackColor: green,
              title: Text(
                title,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              subtitle: Text(enabled ? '$subtitle • $timeLabel' : 'បិទ'),
            ),
            if (enabled) ...[
              const Divider(height: 1, indent: 16, endIndent: 16),
              ListTile(
                key: Key('${kind.name}ReminderTimeButton'),
                enabled: saving == null,
                onTap: () => onPickTime(kind),
                leading: const Icon(Icons.schedule_rounded, color: green),
                title: const Text('ម៉ោងរំលឹក'),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      timeLabel,
                      style: const TextStyle(
                        color: green,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Icon(Icons.chevron_right_rounded),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
