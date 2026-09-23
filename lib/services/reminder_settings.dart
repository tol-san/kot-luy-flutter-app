import 'package:flutter/material.dart';

// ---- Notification message helpers ----
const dailyReminderMessage = 'ថ្ងៃនេះបានកត់ត្រាការចំណាយរបស់អ្នកហើយឬនៅ? 😊';

const weeklyReminderMessage = 'មើលសង្ខេបចំណាយសប្ដាហ៍មុនរបស់អ្នក';

const monthlyReminderMessage = 'មើលសង្ខេបចំណាយខែមុនរបស់អ្នក';

/// Settings model for all three reminder types (daily, weekly, monthly).
@immutable
class ReminderSettings {
  const ReminderSettings({
    required this.dailyEnabled,
    required this.dailyTime,
    required this.weeklyEnabled,
    required this.weeklyTime,
    required this.monthlyEnabled,
    required this.monthlyTime,
  });

  const ReminderSettings.defaults()
    : dailyEnabled = false,
      dailyTime = const TimeOfDay(hour: 20, minute: 0),
      weeklyEnabled = false,
      weeklyTime = const TimeOfDay(hour: 9, minute: 0),
      monthlyEnabled = false,
      monthlyTime = const TimeOfDay(hour: 9, minute: 0);

  final bool dailyEnabled;
  final TimeOfDay dailyTime;
  final bool weeklyEnabled;
  final TimeOfDay weeklyTime;
  final bool monthlyEnabled;
  final TimeOfDay monthlyTime;

  bool enabledFor(ReminderKind kind) => switch (kind) {
    ReminderKind.daily => dailyEnabled,
    ReminderKind.weekly => weeklyEnabled,
    ReminderKind.monthly => monthlyEnabled,
  };

  TimeOfDay timeFor(ReminderKind kind) => switch (kind) {
    ReminderKind.daily => dailyTime,
    ReminderKind.weekly => weeklyTime,
    ReminderKind.monthly => monthlyTime,
  };

  ReminderSettings copyWith({
    ReminderKind? kind,
    bool? enabled,
    TimeOfDay? time,
  }) {
    if (kind == null) return this;
    return ReminderSettings(
      dailyEnabled: kind == ReminderKind.daily
          ? enabled ?? dailyEnabled
          : dailyEnabled,
      dailyTime: kind == ReminderKind.daily ? time ?? dailyTime : dailyTime,
      weeklyEnabled: kind == ReminderKind.weekly
          ? enabled ?? weeklyEnabled
          : weeklyEnabled,
      weeklyTime: kind == ReminderKind.weekly ? time ?? weeklyTime : weeklyTime,
      monthlyEnabled: kind == ReminderKind.monthly
          ? enabled ?? monthlyEnabled
          : monthlyEnabled,
      monthlyTime: kind == ReminderKind.monthly
          ? time ?? monthlyTime
          : monthlyTime,
    );
  }
}

enum ReminderKind { daily, weekly, monthly }
