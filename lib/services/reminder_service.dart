import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import 'package:kot_luy/services/reminder_settings.dart';

export 'package:kot_luy/services/reminder_settings.dart'
    show ReminderKind, ReminderSettings,
        dailyReminderMessage, weeklyReminderMessage, monthlyReminderMessage;


abstract class ReminderService {
  VoidCallback? onOpenExpense;
  ValueChanged<ReminderKind>? onOpenSummary;

  Future<void> initialize();
  Future<void> activateDefaultReminders();
  Future<ReminderSettings> loadSettings();
  Future<bool> setEnabled(ReminderKind kind, bool enabled);
  Future<void> updateTime(ReminderKind kind, TimeOfDay time);
  Future<void> syncSummaryAmounts({
    required int weeklyAmount,
    required int monthlyAmount,
  });
  Future<void> openSystemNotificationSettings();
  Future<bool> isPermissionAllowed();
  bool takePendingOpenExpense();
  ReminderKind? takePendingSummary();
}

class LocalReminderService implements ReminderService {
  LocalReminderService({FlutterLocalNotificationsPlugin? notifications})
    : _notifications = notifications ?? FlutterLocalNotificationsPlugin();

  static const _dailyId = 7001;
  static const _weeklyId = 7002;
  static const _monthlyId = 7003;
  static const _channelId = 'expense_reminders_v2';
  static const _dailyPayload = 'open_add_expense';
  static const _weeklyPayload = 'open_weekly_report';
  static const _monthlyPayload = 'open_monthly_report';

  final FlutterLocalNotificationsPlugin _notifications;
  Future<void>? _initialization;
  bool _initialized = false;
  bool _pendingOpenExpense = false;
  ReminderKind? _pendingSummary;
  int _weeklyAmount = 0;
  int _monthlyAmount = 0;

  @override
  VoidCallback? onOpenExpense;
  @override
  ValueChanged<ReminderKind>? onOpenSummary;

  bool get _isMobile =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  @override
  Future<bool> isPermissionAllowed() => _permissionAllowed();

  @override
  Future<void> initialize() => _initialization ??= _initialize();

  Future<void> _initialize() async {
    if (!_isMobile) return;
    try {
      tz_data.initializeTimeZones();
      try {
        final timezone = await FlutterTimezone.getLocalTimezone();
        tz.setLocalLocation(tz.getLocation(timezone.identifier));
      } catch (_) {
        try {
          tz.setLocalLocation(tz.getLocation('Asia/Phnom_Penh'));
        } catch (_) {
          try {
            tz.setLocalLocation(tz.getLocation('Asia/Bangkok'));
          } catch (_) {
            tz.setLocalLocation(tz.UTC);
          }
        }
      }
      const initialization = InitializationSettings(
        android: AndroidInitializationSettings('ic_notification'),
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
      );
      await _notifications.initialize(
        settings: initialization,
        onDidReceiveNotificationResponse: _handleResponse,
      );
      try {
        final androidPlugin = _notifications
            .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin
            >();
        await androidPlugin?.deleteNotificationChannel(
          channelId: 'expense_reminders',
        );
        await androidPlugin?.createNotificationChannel(
          const AndroidNotificationChannel(
            _channelId,
            'ការរំលឹកចំណាយ',
            description: 'រំលឹកការកត់ និងសង្ខេបចំណាយ',
            importance: Importance.high,
            playSound: true,
            enableVibration: true,
          ),
        );
      } catch (_) {}
      _initialized = true;
      final launch = await _notifications.getNotificationAppLaunchDetails();
      if (launch?.didNotificationLaunchApp ?? false) {
        _rememberPayload(launch?.notificationResponse?.payload);
      }

      try {
        final settings = await loadSettings();
        final pending = await _notifications.pendingNotificationRequests();
        if (settings.dailyEnabled && !pending.any((r) => r.id == _dailyId)) {
          await _scheduleDaily(settings.dailyTime);
        }
        if (settings.weeklyEnabled && !pending.any((r) => r.id == _weeklyId)) {
          await _scheduleWeekly(settings.weeklyTime);
        }
        if (settings.monthlyEnabled && !pending.any((r) => r.id == _monthlyId)) {
          await _scheduleMonthly(settings.monthlyTime);
        }
      } catch (_) {}
    } catch (_) {
      _initialized = false;
    }
  }

  @override
  Future<void> activateDefaultReminders() async {
    await initialize();
    if (!_initialized) return;
    var settings = await loadSettings();
    if (!settings.monthlyEnabled || await _permissionAllowed()) return;
    if (!await _requestPermission()) {
      settings = settings.copyWith(kind: ReminderKind.monthly, enabled: false);
      await _save(settings);
    }
  }

  void _handleResponse(NotificationResponse response) {
    _dispatchPayload(response.payload);
  }

  void _dispatchPayload(String? payload) {
    final kind = _kindForPayload(payload);
    if (payload == _dailyPayload) {
      final callback = onOpenExpense;
      if (callback == null) {
        _pendingOpenExpense = true;
      } else {
        callback();
      }
    } else if (kind != null) {
      final callback = onOpenSummary;
      if (callback == null) {
        _pendingSummary = kind;
      } else {
        callback(kind);
      }
    }
  }

  void _rememberPayload(String? payload) {
    _dispatchPayload(payload);
  }

  ReminderKind? _kindForPayload(String? payload) => switch (payload) {
    _weeklyPayload => ReminderKind.weekly,
    _monthlyPayload => ReminderKind.monthly,
    _ => null,
  };

  @override
  bool takePendingOpenExpense() {
    final pending = _pendingOpenExpense;
    _pendingOpenExpense = false;
    return pending;
  }

  @override
  ReminderKind? takePendingSummary() {
    final pending = _pendingSummary;
    _pendingSummary = null;
    return pending;
  }

  @override
  Future<ReminderSettings> loadSettings() async {
    final preferences = await SharedPreferences.getInstance();
    _weeklyAmount = preferences.getInt('last_weekly_amount') ?? _weeklyAmount;
    _monthlyAmount = preferences.getInt('last_monthly_amount') ?? _monthlyAmount;
    return ReminderSettings(
      dailyEnabled: preferences.getBool('daily_reminder_enabled') ?? false,
      dailyTime: TimeOfDay(
        hour: preferences.getInt('daily_reminder_hour') ?? 20,
        minute: preferences.getInt('daily_reminder_minute') ?? 0,
      ),
      weeklyEnabled: preferences.getBool('weekly_reminder_enabled') ?? false,
      weeklyTime: TimeOfDay(
        hour: preferences.getInt('weekly_reminder_hour') ?? 9,
        minute: preferences.getInt('weekly_reminder_minute') ?? 0,
      ),
      monthlyEnabled: preferences.getBool('monthly_reminder_enabled') ?? false,
      monthlyTime: TimeOfDay(
        hour: preferences.getInt('monthly_reminder_hour') ?? 9,
        minute: preferences.getInt('monthly_reminder_minute') ?? 0,
      ),
    );
  }

  @override
  Future<bool> setEnabled(ReminderKind kind, bool enabled) async {
    await initialize();
    if (!_initialized) return false;
    var settings = await loadSettings();
    if (enabled && !await _permissionAllowed()) {
      if (!await _requestPermission()) return false;
    }
    settings = settings.copyWith(kind: kind, enabled: enabled);
    try {
      if (!enabled) {
        await _notifications.cancel(id: _idFor(kind));
      } else {
        await _schedule(kind, settings.timeFor(kind));
      }
      await _save(settings);
      return true;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<void> updateTime(ReminderKind kind, TimeOfDay time) async {
    await initialize();
    var settings = await loadSettings();
    settings = settings.copyWith(kind: kind, time: time);
    if (settings.enabledFor(kind) && _initialized) await _schedule(kind, time);
    await _save(settings);
  }

  @override
  Future<void> syncSummaryAmounts({
    required int weeklyAmount,
    required int monthlyAmount,
  }) async {
    await initialize();
    _weeklyAmount = weeklyAmount;
    _monthlyAmount = monthlyAmount;
    final preferences = await SharedPreferences.getInstance();
    await Future.wait([
      preferences.setInt('last_weekly_amount', weeklyAmount),
      preferences.setInt('last_monthly_amount', monthlyAmount),
    ]);
    if (!_initialized || !await _permissionAllowed()) return;
    final settings = await loadSettings();
    if (settings.weeklyEnabled) await _scheduleWeekly(settings.weeklyTime);
    if (settings.monthlyEnabled) await _scheduleMonthly(settings.monthlyTime);
  }

  int _idFor(ReminderKind kind) => switch (kind) {
    ReminderKind.daily => _dailyId,
    ReminderKind.weekly => _weeklyId,
    ReminderKind.monthly => _monthlyId,
  };

  Future<void> _schedule(ReminderKind kind, TimeOfDay time) => switch (kind) {
    ReminderKind.daily => _scheduleDaily(time),
    ReminderKind.weekly => _scheduleWeekly(time),
    ReminderKind.monthly => _scheduleMonthly(time),
  };

  Future<void> _scheduleDaily(TimeOfDay time) async {
    final now = tz.TZDateTime.now(tz.local);
    var scheduled = _atTime(now, time);
    if (!scheduled.isAfter(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }
    await _scheduleNotification(
      id: _dailyId,
      title: dailyReminderMessage,
      payload: _dailyPayload,
      scheduled: scheduled,
      repeat: DateTimeComponents.time,
    );
  }

  Future<void> _scheduleWeekly(TimeOfDay time) async {
    final now = tz.TZDateTime.now(tz.local);
    var scheduled = _atTime(now, time);
    final daysToMonday = (DateTime.monday - scheduled.weekday + 7) % 7;
    scheduled = scheduled.add(Duration(days: daysToMonday));
    if (!scheduled.isAfter(now)) {
      scheduled = scheduled.add(const Duration(days: 7));
    }
    await _scheduleNotification(
      id: _weeklyId,
      title: weeklyReminderMessage(_weeklyAmount),
      payload: _weeklyPayload,
      scheduled: scheduled,
      repeat: DateTimeComponents.dayOfWeekAndTime,
    );
  }

  Future<void> _scheduleMonthly(TimeOfDay time) async {
    final now = tz.TZDateTime.now(tz.local);
    var scheduled = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      1,
      time.hour,
      time.minute,
    );
    if (!scheduled.isAfter(now)) {
      final nextYear = now.month == 12 ? now.year + 1 : now.year;
      final nextMonth = now.month == 12 ? 1 : now.month + 1;
      scheduled = tz.TZDateTime(
        tz.local,
        nextYear,
        nextMonth,
        1,
        time.hour,
        time.minute,
      );
    }
    await _scheduleNotification(
      id: _monthlyId,
      title: monthlyReminderMessage(_monthlyAmount),
      payload: _monthlyPayload,
      scheduled: scheduled,
      repeat: DateTimeComponents.dayOfMonthAndTime,
    );
  }

  tz.TZDateTime _atTime(tz.TZDateTime date, TimeOfDay time) => tz.TZDateTime(
    tz.local,
    date.year,
    date.month,
    date.day,
    time.hour,
    time.minute,
  );

  Future<void> _scheduleNotification({
    required int id,
    required String title,
    String? body,
    required String payload,
    required tz.TZDateTime scheduled,
    DateTimeComponents? repeat,
  }) async {
    await _notifications.cancel(id: id);
    var scheduleMode = AndroidScheduleMode.inexactAllowWhileIdle;
    if (defaultTargetPlatform == TargetPlatform.android) {
      try {
        final androidPlugin = _notifications
            .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin
            >();
        final canExact =
            await androidPlugin?.canScheduleExactNotifications() ?? false;
        if (canExact) {
          scheduleMode = AndroidScheduleMode.exactAllowWhileIdle;
        }
      } catch (_) {}
    }

    await _notifications.zonedSchedule(
      id: id,
      title: title,
      body: body,
      payload: payload,
      scheduledDate: scheduled,
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          'ការរំលឹកចំណាយ',
          channelDescription: 'រំលឹកការកត់ និងសង្ខេបចំណាយ',
          importance: Importance.high,
          priority: Priority.high,
          playSound: true,
          enableVibration: true,
        ),
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
      androidScheduleMode: scheduleMode,
      matchDateTimeComponents: repeat,
    );
  }

  Future<bool> _permissionAllowed() async {
    if (defaultTargetPlatform == TargetPlatform.android) {
      final androidPlugin = _notifications
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      if (androidPlugin == null) return true;
      return await androidPlugin.areNotificationsEnabled() ?? true;
    }
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      final permissions = await _notifications
          .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin
          >()
          ?.checkPermissions();
      return permissions?.isEnabled ?? false;
    }
    return false;
  }

  Future<bool> _requestPermission() async {
    if (defaultTargetPlatform == TargetPlatform.android) {
      final androidPlugin = _notifications
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      if (androidPlugin == null) return true;
      return await androidPlugin.requestNotificationsPermission() ?? false;
    }
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      return await _notifications
              .resolvePlatformSpecificImplementation<
                IOSFlutterLocalNotificationsPlugin
              >()
              ?.requestPermissions(alert: true, badge: false, sound: true) ??
          false;
    }
    return false;
  }

  @override
  Future<void> openSystemNotificationSettings() async {
    if (defaultTargetPlatform == TargetPlatform.android) {
      try {
        const channel = MethodChannel('kot_luy/app_settings');
        final success =
            await channel.invokeMethod<bool>('openNotificationSettings');
        if (success == true) return;
      } catch (_) {}

      try {
        await _notifications
            .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin
            >()
            ?.openAppNotificationSettings();
      } catch (_) {}
    } else if (defaultTargetPlatform == TargetPlatform.iOS) {
      try {
        await _notifications
            .resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin
            >()
            ?.openAppNotificationSettings();
      } catch (_) {}
    }
  }

  Future<void> _save(ReminderSettings settings) async {
    final preferences = await SharedPreferences.getInstance();
    await Future.wait([
      preferences.setBool('daily_reminder_enabled', settings.dailyEnabled),
      preferences.setInt('daily_reminder_hour', settings.dailyTime.hour),
      preferences.setInt('daily_reminder_minute', settings.dailyTime.minute),
      preferences.setBool('weekly_reminder_enabled', settings.weeklyEnabled),
      preferences.setInt('weekly_reminder_hour', settings.weeklyTime.hour),
      preferences.setInt('weekly_reminder_minute', settings.weeklyTime.minute),
      preferences.setBool('monthly_reminder_enabled', settings.monthlyEnabled),
      preferences.setInt('monthly_reminder_hour', settings.monthlyTime.hour),
      preferences.setInt(
        'monthly_reminder_minute',
        settings.monthlyTime.minute,
      ),
    ]);
  }
}
