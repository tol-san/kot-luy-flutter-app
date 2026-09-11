import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kot_luy/screens/reminder_settings_sheet.dart';
import 'package:kot_luy/services/reminder_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FakeReminderService implements ReminderService {
  FakeReminderService({
    this.settings = const ReminderSettings.defaults(),
    this.permissionGranted = true,
  });

  ReminderSettings settings;
  bool permissionGranted;
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
    if (!permissionGranted) return false;
    settings = settings.copyWith(kind: kind, enabled: enabled);
    return true;
  }

  @override
  Future<void> updateTime(ReminderKind kind, TimeOfDay time) async {
    updateTimeCalls++;
    settings = settings.copyWith(kind: kind, time: time);
  }

  @override
  Future<void> syncSummaryAmounts({
    required int weeklyAmount,
    required int monthlyAmount,
  }) async {}

  @override
  Future<void> openSystemNotificationSettings() async {
    openSystemSettingsCalls++;
  }

  @override
  bool takePendingOpenExpense() => false;

  @override
  ReminderKind? takePendingSummary() => null;
}

void main() {
  test('summary copy contains the current formatted amount only', () {
    expect(dailyReminderMessage, 'ថ្ងៃនេះបានកត់ត្រាការចំណាយរបស់អ្នកហើយឬនៅ? 😊');
    expect(weeklyReminderMessage(120000), 'សប្ដាហ៍នេះអ្នកបានចំណាយ 120,000 ៛');
    expect(monthlyReminderMessage(350000), 'ខែនេះអ្នកបានចំណាយ 350,000 ៛');
  });

  test('all reminders default to disabled in persisted settings', () async {
    SharedPreferences.setMockInitialValues({});
    final settings = await LocalReminderService().loadSettings();
    expect(settings.dailyEnabled, isFalse);
    expect(settings.weeklyEnabled, isFalse);
    expect(settings.monthlyEnabled, isFalse);
  });

  Future<void> mount(WidgetTester tester, FakeReminderService service) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
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
}
