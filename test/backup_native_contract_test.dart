import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kot_luy/data/expense_repository.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

// The Android regression test consumes these real repository databases. Never
// replace them with hand-written SQL: that previously hid schema drift.
void main() {
  test(
    'exports current and upgraded repository databases for Android backup',
    () async {
      sqfliteFfiInit();
      final directory = Directory('build/backup-contract')
        ..createSync(recursive: true);
      for (final oldVersion in [0, 2, 3, 4]) {
        final path = '${directory.absolute.path}/repository-$oldVersion.db';
        await databaseFactoryFfi.deleteDatabase(path);
        if (oldVersion != 0) {
          final old = await databaseFactoryFfi.openDatabase(path);
          await old.execute(
            'CREATE TABLE categories (id TEXT PRIMARY KEY, label TEXT NOT NULL, color_value INTEGER NOT NULL, sort_order INTEGER NOT NULL, is_custom INTEGER NOT NULL DEFAULT 0)',
          );
          await old.execute(
            "INSERT INTO categories VALUES ('lunch', 'បាយថ្ងៃត្រង់', 4281680715, 0, 0)",
          );
          await old.execute(
            "CREATE TABLE expenses (id INTEGER PRIMARY KEY AUTOINCREMENT, title TEXT NOT NULL, amount INTEGER NOT NULL, category TEXT NOT NULL, date INTEGER NOT NULL, note TEXT NOT NULL DEFAULT '')",
          );
          if (oldVersion >= 4) {
            await old.execute(
              'ALTER TABLE categories ADD COLUMN is_archived INTEGER NOT NULL DEFAULT 0',
            );
          }
          await old.setVersion(oldVersion);
          await old.close();
        }
        final repository = await ExpenseRepository.open(
          factory: databaseFactoryFfi,
          path: path,
        );
        final db = repository.database;
        final category = (await db.query('categories')).first['id'] as String;
        await db.update(
          'categories',
          {'is_archived': 1},
          where: 'id = ?',
          whereArgs: [category],
        );
        await db.insert('expenses', {
          'title': 'បាយ',
          'amount': 999999999999,
          'category': category,
          'date': 1725600000000,
          'note': '',
        });
        await repository.close();
        expect(File(path).existsSync(), isTrue);
      }
    },
  );
}
