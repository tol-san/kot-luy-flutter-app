import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:kot_luy/backup/backup_snapshot.dart';
import 'package:kot_luy/backup/drive_backup.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('DriveBackupStatus & DriveBackupItem', () {
    test('parses status map properly', () {
      final now = DateTime.now().millisecondsSinceEpoch;
      final status = DriveBackupStatus.fromMap({
        'email': 'user@example.com',
        'automatic': true,
        'wifiOnly': false,
        'lastSuccess': now,
        'lastError': null,
        'queued': false,
        'lastCount': 42,
      });

      expect(status.isConnected, isTrue);
      expect(status.email, 'user@example.com');
      expect(status.automatic, isTrue);
      expect(status.wifiOnly, isFalse);
      expect(status.lastSuccess?.millisecondsSinceEpoch, now);
      expect(status.lastError, isNull);
      expect(status.lastCount, 42);
    });

    test('handles null status map', () {
      final status = DriveBackupStatus.fromMap(null);
      expect(status.isConnected, isFalse);
      expect(status.email, isNull);
      expect(status.automatic, isFalse);
      expect(status.wifiOnly, isFalse);
    });

    test('parses backup item map correctly', () {
      final item = DriveBackupItem.fromMap({
        'id': 'file_123',
        'name': 'Kot Luy 2026-09-06.json',
        'createdTime': '2026-09-06T12:30:00.000Z',
        'size': '15360',
      });

      expect(item.id, 'file_123');
      expect(item.name, 'Kot Luy 2026-09-06.json');
      expect(item.size, 15360);
      expect(item.createdTime, isNotNull);
    });
  });

  group('BackupSnapshot', () {
    late Database db;

    setUp(() async {
      db = await databaseFactory.openDatabase(inMemoryDatabasePath);
      await db.execute('''CREATE TABLE categories (
        id TEXT PRIMARY KEY,
        label TEXT NOT NULL,
        color_value INTEGER NOT NULL,
        sort_order INTEGER NOT NULL,
        is_custom INTEGER NOT NULL DEFAULT 0,
        is_archived INTEGER NOT NULL DEFAULT 0
      )''');
      await db.execute('''CREATE TABLE expenses (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        title TEXT NOT NULL,
        amount INTEGER NOT NULL CHECK(amount > 0 AND amount <= 999999999999),
        category TEXT NOT NULL,
        date INTEGER NOT NULL,
        note TEXT NOT NULL DEFAULT ''
      )''');

      await db.insert('categories', {
        'id': 'lunch',
        'label': 'បាយថ្ងៃត្រង់',
        'color_value': 0xFF35634B,
        'sort_order': 0,
        'is_custom': 0,
      });
      await db.insert('expenses', {
        'id': 1,
        'title': 'បាយសាច់ជ្រូក',
        'amount': 6000,
        'category': 'lunch',
        'date': 1725600000000,
        'note': 'ឆ្ងាញ់',
      });
    });

    tearDown(() async {
      await db.close();
    });

    test('capture generates valid JSON and parse restores it', () async {
      final jsonString = await BackupSnapshot.capture(db);
      expect(jsonString, contains('kot_luy_backup'));
      expect(jsonString, contains('បាយសាច់ជ្រូក'));

      final snapshot = BackupSnapshot.parse(jsonString);
      expect(snapshot.expenses.length, 1);
      expect(snapshot.categories.length, 1);
      expect(snapshot.expenses.first['title'], 'បាយសាច់ជ្រូក');
      expect(snapshot.categories.first['id'], 'lunch');
    });

    test(
      'archive status survives backup and legacy backups remain active',
      () async {
        await db.update('categories', {'is_archived': 1});
        final captured = await BackupSnapshot.capture(db);
        await db.update('categories', {'is_archived': 0});
        await BackupSnapshot.parse(captured).restore(db);
        expect((await db.query('categories')).single['is_archived'], 1);
        expect((await db.query('expenses')).single['amount'], 6000);
        final legacy = jsonDecode(captured) as Map<String, dynamic>;
        (legacy['categories'][0] as Map).remove('is_archived');
        await BackupSnapshot.parse(jsonEncode(legacy)).restore(db);
        expect((await db.query('categories')).single['is_archived'], 0);
      },
    );

    test('rejects invalid JSON structure', () {
      expect(
        () => BackupSnapshot.parse('{"invalid": true}'),
        throwsA(isA<FormatException>()),
      );
      expect(
        () => BackupSnapshot.parse(
          jsonEncode({
            'format': 'wrong_format',
            'version': 1,
            'schemaVersion': 2,
            'createdAt': 12345,
            'expenses': [],
            'categories': [],
          }),
        ),
        throwsA(isA<FormatException>()),
      );
    });

    test('restores snapshot into database and preserves safety copy', () async {
      final captured = await BackupSnapshot.capture(db);

      // Modify database to simulate changes
      await db.delete('expenses');
      var expenses = await db.query('expenses');
      expect(expenses, isEmpty);

      // Restore
      final snapshot = BackupSnapshot.parse(captured);
      await snapshot.restore(db);

      // Verify restored
      expenses = await db.query('expenses');
      expect(expenses.length, 1);
      expect(expenses.first['title'], 'បាយសាច់ជ្រូក');

      // Verify safety copy was created during restore
      final safety = await BackupSnapshot.safetyCopy(db);
      expect(safety, isNotNull);
    });
  });
}
