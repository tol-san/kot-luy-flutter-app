import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kot_luy/globals.dart';
import 'package:kot_luy/screens/reminder_settings_sheet.dart';
import 'package:kot_luy/services/reminder_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FakeReminderService implements ReminderService {
  FakeReminderService({
    this.settings = const ReminderSettings.defaults(),
    this.permissionGranted = true,
    this.shouldSucceed = true,
  });

  ReminderSettings settings;
  bool permissionGranted;
  bool shouldSucceed;
  int setEnabledCalls = 0;
  int updateTimeCalls = 0;
  int openSystemSettingsCalls = 0;

  @override
  VoidCallback? onOpenExpense;
  @override
  ValueChanged<ReminderKind>? onOpenSummary;

  @override
  Future<void> initialize() async {}

  @override
  Future<void> activateDefaultReminders() async {}

  @override
  Future<ReminderSettings> loadSettings() async => settings;

  @override
  Future<bool> setEnabled(ReminderKind kind, bool enabled) async {
    setEnabledCalls++;
    if (!permissionGranted || !shouldSucceed) return false;
    settings = settings.copyWith(kind: kind, enabled: enabled);
    return true;
  }

  @override
  Future<void> updateTime(ReminderKind kind, TimeOfDay time) async {
    updateTimeCalls++;
    settings = settings.copyWith(kind: kind, time: time);
  }

  @override
  Future<void> openSystemNotificationSettings() async {
    openSystemSettingsCalls++;
  }

  @override
  Future<bool> isPermissionAllowed() async => permissionGranted;

  @override
  bool takePendingOpenExpense() => false;

  @override
  ReminderKind? takePendingSummary() => null;
}

void main() {
  test('summary reminders do not include an amount that can become stale', () {
    expect(dailyReminderMessage, 'ថ្ងៃនេះបានកត់ត្រាការចំណាយរបស់អ្នកហើយឬនៅ? 😊');
    expect(weeklyReminderMessage, 'មើលសង្ខេបចំណាយសប្ដាហ៍មុនរបស់អ្នក');
    expect(monthlyReminderMessage, 'មើលសង្ខេបចំណាយខែមុនរបស់អ្នក');
  });

  test('all reminders default to disabled in persisted settings', () async {
    SharedPreferences.setMockInitialValues({});
    final settings = await LocalReminderService().loadSettings();
    expect(settings.dailyEnabled, isFalse);
    expect(settings.weeklyEnabled, isFalse);
    expect(settings.monthlyEnabled, isFalse);
    expect(settings.dailyTime, const TimeOfDay(hour: 20, minute: 0));
    expect(settings.weeklyTime, const TimeOfDay(hour: 9, minute: 0));
    expect(settings.monthlyTime, const TimeOfDay(hour: 9, minute: 0));

    const defaults = ReminderSettings.defaults();
    expect(defaults.dailyTime, const TimeOfDay(hour: 20, minute: 0));
    expect(defaults.weeklyTime, const TimeOfDay(hour: 9, minute: 0));
    expect(defaults.monthlyTime, const TimeOfDay(hour: 9, minute: 0));
  });

  Future<void> mount(WidgetTester tester, FakeReminderService service) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        scaffoldMessengerKey: rootMessengerKey,
        home: Scaffold(body: ReminderSettingsSheet(reminderService: service)),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('all reminders are disabled by default', (tester) async {
    final service = FakeReminderService();
    await mount(tester, service);

    expect(find.text('សង្ខេបចំណាយប្រចាំសប្ដាហ៍'), findsOneWidget);
    expect(find.text('សង្ខេបចំណាយប្រចាំខែ'), findsOneWidget);
    expect(find.text('បិទ'), findsNWidgets(3));
    expect(
      tester
          .widget<SwitchListTile>(
            find.byKey(const Key('monthlyReminderSwitch')),
          )
          .value,
      isFalse,
    );
    expect(find.byKey(const Key('monthlyReminderTimeButton')), findsNothing);
  });

  testWidgets('user can enable weekly summary independently', (tester) async {
    final service = FakeReminderService();
    await mount(tester, service);

    expect(find.byKey(const Key('weeklyReminderTimeButton')), findsNothing);
    await tester.tap(find.byKey(const Key('weeklyReminderSwitch')));
    await tester.pumpAndSettle();

    expect(service.setEnabledCalls, 1);
    expect(service.settings.weeklyEnabled, isTrue);
    expect(find.byKey(const Key('weeklyReminderTimeButton')), findsOneWidget);
    expect(find.textContaining('ផ្ញើរៀងរាល់ថ្ងៃចន្ទ'), findsOneWidget);
  });

  testWidgets('denied access leaves the selected reminder off', (tester) async {
    final service = FakeReminderService(permissionGranted: false);
    await mount(tester, service);

    await tester.tap(find.byKey(const Key('weeklyReminderSwitch')));
    await tester.pumpAndSettle();

    expect(service.settings.weeklyEnabled, isFalse);
    expect(find.textContaining('មិនអាចបើកការរំលឹកបានទេ'), findsOneWidget);
    await tester.tap(find.text('បើកការកំណត់'));
    await tester.pump();
    expect(service.openSystemSettingsCalls, 1);
  });

  testWidgets('daily reminder can be enabled and disabled', (tester) async {
    final service = FakeReminderService();
    await mount(tester, service);

    await tester.tap(find.byKey(const Key('dailyReminderSwitch')));
    await tester.pumpAndSettle();
    expect(service.settings.dailyEnabled, isTrue);
    expect(find.byKey(const Key('dailyReminderTimeButton')), findsOneWidget);

    await tester.tap(find.byKey(const Key('dailyReminderSwitch')));
    await tester.pumpAndSettle();
    expect(service.settings.dailyEnabled, isFalse);
    expect(find.byKey(const Key('dailyReminderTimeButton')), findsNothing);
  });

  testWidgets(
    'scheduling error with permission allowed shows snackbar without dialog',
    (tester) async {
      final service = FakeReminderService(
        permissionGranted: true,
        shouldSucceed: false,
      );
      await mount(tester, service);

      await tester.tap(find.byKey(const Key('dailyReminderSwitch')));
      await tester.pumpAndSettle();

      expect(service.settings.dailyEnabled, isFalse);
      expect(find.textContaining('មិនអាចបើកការរំលឹកបានទេ'), findsNothing);
      expect(
        find.text('មិនអាចកំណត់ការរំលឹកបានទេ។ សូមសាកល្បងម្ដងទៀត។'),
        findsOneWidget,
      );
    },
  );
}
