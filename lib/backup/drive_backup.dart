import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:sqflite/sqflite.dart';

import 'package:kot_luy/backup/backup_snapshot.dart';

/// Represents the current Google Drive backup status and settings.
class DriveBackupStatus {
  const DriveBackupStatus({
    this.email,
    this.automatic = false,
    this.wifiOnly = false,
    this.lastSuccess,
    this.lastError,
    this.queued = false,
    this.lastCount = 0,
  });

  final String? email;
  final bool automatic;
  final bool wifiOnly;
  final DateTime? lastSuccess;
  final String? lastError;
  final bool queued;
  final int lastCount;

  bool get isConnected => email != null && email!.isNotEmpty;

  factory DriveBackupStatus.fromMap(Map<dynamic, dynamic>? map) {
    if (map == null) return const DriveBackupStatus();
    final rawSuccess = map['lastSuccess'];
    final successEpoch = (rawSuccess is num) ? rawSuccess.toInt() : 0;
    return DriveBackupStatus(
      email: map['email'] as String?,
      automatic: map['automatic'] == true,
      wifiOnly: map['wifiOnly'] == true,
      lastSuccess: successEpoch > 0
          ? DateTime.fromMillisecondsSinceEpoch(successEpoch)
          : null,
      lastError: map['lastError'] as String?,
      queued: map['queued'] == true,
      lastCount: (map['lastCount'] as num?)?.toInt() ?? 0,
    );
  }
}

/// Represents a remote backup file stored on Google Drive.
class DriveBackupItem {
  const DriveBackupItem({
    required this.id,
    required this.name,
    this.createdTime,
    this.size,
  });

  final String id;
  final String name;
  final DateTime? createdTime;
  final int? size;

  factory DriveBackupItem.fromMap(Map<dynamic, dynamic> map) {
    DateTime? parsedDate;
    final dateStr = map['createdTime'] as String?;
    if (dateStr != null && dateStr.isNotEmpty) {
      try {
        parsedDate = DateTime.parse(dateStr).toLocal();
      } catch (_) {}
    }
    return DriveBackupItem(
      id: (map['id'] as String?) ?? '',
      name: (map['name'] as String?) ?? 'Kot Luy Backup',
      createdTime: parsedDate,
      size: int.tryParse(map['size']?.toString() ?? ''),
    );
  }
}

/// Android owns authorization and background uploads; no tokens cross into Dart.
class DriveBackup {
  static const channel = MethodChannel('kot_luy/drive_backup');

  static bool get supported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  /// Notifies the native backup engine that local SQLite database changed.
  static Future<void> dataChanged(String databasePath) async {
    try {
      if (!supported) return;
      await channel.invokeMethod<void>('changed', {'path': databasePath});
    } catch (_) {
      // Non-critical background ping; never interrupt data mutations or test runners.
    }
  }

  /// Fetches current backup status and account configuration.
  Future<DriveBackupStatus> getStatus() async {
    if (!supported) return const DriveBackupStatus();
    try {
      final map = await channel.invokeMapMethod<dynamic, dynamic>('status');
      return DriveBackupStatus.fromMap(map);
    } catch (_) {
      return const DriveBackupStatus();
    }
  }

  /// Interactive sign-in and Google Drive authorization.
  Future<DriveBackupStatus> connect() async {
    if (!supported) {
      throw UnsupportedError('Google Drive backup is only supported on Android.');
    }
    final map = await channel.invokeMapMethod<dynamic, dynamic>('connect');
    return DriveBackupStatus.fromMap(map);
  }

  /// Disconnects account and cleans up work.
  Future<DriveBackupStatus> disconnect() async {
    if (!supported) return const DriveBackupStatus();
    final map = await channel.invokeMapMethod<dynamic, dynamic>('disconnect');
    return DriveBackupStatus.fromMap(map);
  }

  /// Updates backup settings (automatic silent backup, Wi-Fi only vs Wi-Fi + SIM).
  Future<DriveBackupStatus> configure({
    required bool automatic,
    required bool wifiOnly,
  }) async {
    if (!supported) return const DriveBackupStatus();
    final map = await channel.invokeMapMethod<dynamic, dynamic>('configure', {
      'automatic': automatic,
      'wifiOnly': wifiOnly,
    });
    return DriveBackupStatus.fromMap(map);
  }

  /// Runs immediate manual backup to Google Drive with progress feedback.
  Future<DriveBackupStatus> backup() async {
    if (!supported) {
      throw UnsupportedError('Google Drive backup is only supported on Android.');
    }
    final map = await channel.invokeMapMethod<dynamic, dynamic>('backup');
    return DriveBackupStatus.fromMap(map);
  }

  /// Lists verified backups stored in Kot Luy Backups folder on Google Drive.
  Future<List<DriveBackupItem>> list() async {
    if (!supported) return const [];
    final items = await channel.invokeListMethod<dynamic>('list') ?? [];
    return items
        .whereType<Map<dynamic, dynamic>>()
        .map(DriveBackupItem.fromMap)
        .toList();
  }

  /// Downloads and verifies backup snapshot JSON from Google Drive.
  Future<String> download(String id) async {
    if (!supported) {
      throw UnsupportedError('Google Drive backup is only supported on Android.');
    }
    final content = await channel.invokeMethod<String>('download', {'id': id});
    if (content == null || content.isEmpty) {
      throw const FormatException('Empty backup content');
    }
    return content;
  }

  /// Safely restores a backup snapshot into the local database.
  Future<void> restore(String id, Database db) async {
    final rawJson = await download(id);
    final snapshot = BackupSnapshot.parse(rawJson);
    await snapshot.restore(db);
    await dataChanged(db.path);
  }
}
