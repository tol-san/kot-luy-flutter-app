import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';

import 'package:kot_luy/backup/drive_backup.dart';
import 'package:kot_luy/models/expense.dart';

class ExpenseRepository {
  ExpenseRepository(this.database);
  final Database database;
  static Future<ExpenseRepository> open({
    DatabaseFactory? factory,
    String? path,
  }) async {
    final dbFactory =
        factory ?? (kIsWeb ? databaseFactoryFfiWeb : databaseFactory);
    // Keep the original filename so existing Kot Luy installations retain data.
    final location =
        path ?? p.join(await dbFactory.getDatabasesPath(), 'kot_loy.db');
    final db = await dbFactory.openDatabase(
      location,
      options: OpenDatabaseOptions(
        version: 4,
        onCreate: (db, version) async {
          await db.execute('''CREATE TABLE expenses (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          title TEXT NOT NULL,
          amount INTEGER NOT NULL CHECK(amount > 0 AND amount <= 999999999999),
          category TEXT NOT NULL,
          date INTEGER NOT NULL,
          note TEXT NOT NULL DEFAULT ''
        )''');
          await db.execute('CREATE INDEX expenses_date ON expenses(date DESC)');
          await _createCategoriesTable(db);
        },
        onUpgrade: (db, oldVersion, newVersion) async {
          if (oldVersion < 2) {
            await _createCategoriesTable(db);
          }
          if (oldVersion < 3) {
            // Upgrade callbacks already run in a transaction. Repair legacy
            // categories once, rather than scanning expenses on every launch.
            await _removeLegacyCategory(db);
            await _deduplicateCategories(db);
          }
          if (oldVersion < 4) {
            final columns = await db.rawQuery('PRAGMA table_info(categories)');
            if (!columns.any((column) => column['name'] == 'is_archived')) {
              await db.execute(
                'ALTER TABLE categories ADD COLUMN '
                'is_archived INTEGER NOT NULL DEFAULT 0',
              );
            }
          }
        },
      ),
    );
    final repo = ExpenseRepository(db);
    unawaited(DriveBackup.dataChanged(db.path));
    return repo;
  }

  static Future<void> _removeLegacyCategory(DatabaseExecutor db) async {
    final remaining = await db.query(
      'categories',
      where: "id != 'other'",
      orderBy: 'sort_order ASC',
      limit: 1,
    );
    if (remaining.isNotEmpty) {
      final fallbackId = remaining.first['id'] as String;
      await db.update('expenses', {
        'category': fallbackId,
      }, where: "category = 'other'");
    }
    await db.delete('categories', where: "id = 'other'");
  }

  static Future<void> _deduplicateCategories(DatabaseExecutor db) async {
    final rows = await db.query(
      'categories',
      orderBy: 'is_custom ASC, sort_order ASC',
    );
    final seen = <String, String>{}; // normalized label -> primary id
    for (final row in rows) {
      final id = row['id'] as String;
      final label = (row['label'] as String).trim().toLowerCase();
      if (seen.containsKey(label)) {
        final primaryId = seen[label]!;
        await db.update(
          'expenses',
          {'category': primaryId},
          where: 'category = ?',
          whereArgs: [id],
        );
        await db.delete('categories', where: 'id = ?', whereArgs: [id]);
      } else {
        seen[label] = id;
      }
    }
  }

  static Future<void> _createCategoriesTable(DatabaseExecutor db) async {
    await db.execute('''CREATE TABLE IF NOT EXISTS categories (
      id TEXT PRIMARY KEY,
      label TEXT NOT NULL,
      color_value INTEGER NOT NULL,
      sort_order INTEGER NOT NULL,
      is_custom INTEGER NOT NULL DEFAULT 0,
      is_archived INTEGER NOT NULL DEFAULT 0
    )''');
    final count =
        Sqflite.firstIntValue(
          await db.rawQuery('SELECT COUNT(*) FROM categories'),
        ) ??
        0;
    if (count == 0) {
      final batch = db.batch();
      for (var i = 0; i < ExpenseCategory.values.length; i++) {
        final c = ExpenseCategory.values[i];
        batch.insert('categories', {
          'id': c.name,
          'label': c.label,
          'color_value': c.color.toARGB32(),
          'sort_order': i,
          'is_custom': 0,
        });
      }
      await batch.commit(noResult: true);
    }
    // Ensure deprecated 'other' is purged from categories table
    await db.delete('categories', where: "id = 'other'");
  }

  Future<List<ExpenseCategory>> getCategories({
    bool includeArchived = false,
  }) async {
    final rows = await database.query('categories', orderBy: 'sort_order ASC');
    if (rows.isEmpty) {
      await _createCategoriesTable(database);
      return ExpenseCategory.values;
    }
    final seenLabels = <String>{};
    var hasDuplicates = false;
    for (final r in rows) {
      final label = (r['label'] as String).trim().toLowerCase();
      if (!seenLabels.add(label)) {
        hasDuplicates = true;
        break;
      }
    }
    if (hasDuplicates) {
      await database.transaction(_deduplicateCategories);
      return getCategories(includeArchived: includeArchived);
    }
    return rows.where((r) => includeArchived || r['is_archived'] != 1).map((r) {
      final id = r['id'] as String;
      final label = r['label'] as String;
      final colorVal = r['color_value'] as int;
      final isCustom = (r['is_custom'] as int? ?? 0) == 1;
      final color = Color(colorVal);
      final defaultMatch = switch (id) {
        'breakfast' => ExpenseCategory.breakfast,
        'lunch' => ExpenseCategory.lunch,
        'dinner' => ExpenseCategory.dinner,
        'fuel' => ExpenseCategory.fuel,
        'coffee' => ExpenseCategory.coffee,
        _ => null,
      };
      return ExpenseCategory(
        name: id,
        label: label,
        icon: defaultMatch?.icon ?? Icons.local_offer_outlined,
        color: color,
        background: ExpenseCategory.autoBackground(color),
        isCustom: isCustom,
        isArchived: r['is_archived'] == 1,
      );
    }).toList();
  }

  Future<ExpenseCategory> addCategory(String label, {Color? color}) async {
    final clean = label.trim();
    if (clean.isEmpty) throw ArgumentError('ឈ្មោះមុខចំណាយមិនអាចទទេបានទេ');
    final current = await getCategories(includeArchived: true);
    final isDuplicate = current.any(
      (c) => c.label.trim().toLowerCase() == clean.toLowerCase(),
    );
    if (isDuplicate) {
      throw ArgumentError('មុខចំណាយនេះមានរួចហើយ។ បើបានលាក់ សូមបង្ហាញវាឡើងវិញ។');
    }
    final customCount = current.where((c) => c.isCustom).length;
    final selectedColor =
        color ??
        ExpenseCategory.autoColors[(customCount + 5) %
            ExpenseCategory.autoColors.length];
    final id = 'custom_${DateTime.now().millisecondsSinceEpoch}';
    final nextOrder = current.length;

    await database.insert('categories', {
      'id': id,
      'label': clean,
      'color_value': selectedColor.toARGB32(),
      'sort_order': nextOrder,
      'is_custom': 1,
    });
    unawaited(DriveBackup.dataChanged(database.path));

    return ExpenseCategory(
      name: id,
      label: clean,
      icon: Icons.local_offer_outlined,
      color: selectedColor,
      background: ExpenseCategory.autoBackground(selectedColor),
      isCustom: true,
    );
  }

  Future<void> deleteCategory(String id) async {
    await database.transaction((txn) async {
      final usage = await txn.query(
        'expenses',
        columns: ['id'],
        where: 'category = ?',
        whereArgs: [id],
        limit: 1,
      );
      final remaining = await txn.query(
        'categories',
        where: 'id != ? AND is_archived = 0',
        whereArgs: [id],
        orderBy: 'sort_order ASC',
        limit: 1,
      );
      if (remaining.isEmpty) {
        throw StateError('មិនអាចលុបបានទេ ត្រូវមានមុខចំណាយយ៉ាងហោចណាស់មួយ');
      }
      if (usage.isNotEmpty) {
        await txn.update(
          'categories',
          {'is_archived': 1},
          where: 'id = ?',
          whereArgs: [id],
        );
      } else {
        await txn.delete('categories', where: 'id = ?', whereArgs: [id]);
      }
    });
    unawaited(DriveBackup.dataChanged(database.path));
  }

  Future<void> reorderCategories(List<String> ids) async {
    await database.transaction((txn) async {
      final batch = txn.batch();
      for (var i = 0; i < ids.length; i++) {
        batch.update(
          'categories',
          {'sort_order': i},
          where: 'id = ?',
          whereArgs: [ids[i]],
        );
      }
      await batch.commit(noResult: true);
    });
    unawaited(DriveBackup.dataChanged(database.path));
  }

  Future<List<Expense>> all({List<ExpenseCategory>? categories}) async {
    // Always resolve historical metadata, even when the caller supplies active choices.
    final resolvedCategories = await getCategories(includeArchived: true);
    final rows = await database.query(
      'expenses',
      orderBy: 'date DESC, id DESC',
    );
    return rows.map((r) => Expense.fromMap(r, resolvedCategories)).toList();
  }

  Future<bool> categoryHasExpenses(String id) async => (await database.query(
    'expenses',
    columns: ['id'],
    where: 'category = ?',
    whereArgs: [id],
    limit: 1,
  )).isNotEmpty;

  Future<void> restoreCategory(String id) async {
    await database.update(
      'categories',
      {'is_archived': 0},
      where: 'id = ?',
      whereArgs: [id],
    );
    unawaited(DriveBackup.dataChanged(database.path));
  }

  Future<void> save(Expense expense) async {
    if (expense.title.trim().isEmpty ||
        expense.amount <= 0 ||
        expense.amount > 999999999999) {
      throw ArgumentError('Invalid expense');
    }
    if (expense.id == null) {
      await database.insert('expenses', expense.toMap());
    } else {
      final count = await database.update(
        'expenses',
        expense.toMap(),
        where: 'id = ?',
        whereArgs: [expense.id],
      );
      if (count == 0) throw StateError('Expense no longer exists');
    }
    unawaited(DriveBackup.dataChanged(database.path));
  }

  Future<void> delete(int id) async {
    await database.delete('expenses', where: 'id = ?', whereArgs: [id]);
    unawaited(DriveBackup.dataChanged(database.path));
  }

  Future<void> deleteMultiple(List<int> ids) async {
    if (ids.isEmpty) return;
    await database.transaction((txn) async {
      final batch = txn.batch();
      for (final id in ids) {
        batch.delete('expenses', where: 'id = ?', whereArgs: [id]);
      }
      await batch.commit(noResult: true);
    });
    unawaited(DriveBackup.dataChanged(database.path));
  }

  Future<void> close() => database.close();
}
