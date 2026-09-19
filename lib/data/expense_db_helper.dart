import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';

import 'package:kot_luy/models/expense.dart';

/// Low-level SQLite schema helpers used by [ExpenseRepository].
///
/// All methods are static and operate on a [DatabaseExecutor] so they can be
/// called inside transactions as well as on the top-level [Database].
class ExpenseDbHelper {
  ExpenseDbHelper._();

  static Future<void> createCategoriesTable(DatabaseExecutor db) async {
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

  static Future<void> removeLegacyCategory(DatabaseExecutor db) async {
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

  static Future<void> deduplicateCategories(DatabaseExecutor db) async {
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

  static Future<void> refreshCategoryColors(DatabaseExecutor db) async {
    final rows = await db.query(
      'categories',
      orderBy: 'is_custom ASC, sort_order ASC, id ASC',
    );
    final defaults = {for (final c in ExpenseCategory.values) c.name: c.color};
    final used = <Color>[];
    for (final row in rows) {
      final id = row['id'] as String;
      final color = defaults[id] ?? ExpenseCategory.nextColor(used);
      used.add(color);
      await db.update(
        'categories',
        {'color_value': color.toARGB32()},
        where: 'id = ?',
        whereArgs: [id],
      );
    }
  }

  static Future<void> migrateToV6(DatabaseExecutor db) async {
    final columns = await db.rawQuery('PRAGMA table_info(expenses)');
    final hasTitle = columns.any((column) => column['name'] == 'title');
    if (hasTitle) {
      await db.execute('''CREATE TABLE expenses_v6 (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        amount INTEGER NOT NULL CHECK(amount > 0 AND amount <= 999999999999),
        category TEXT NOT NULL,
        date INTEGER NOT NULL,
        note TEXT NOT NULL DEFAULT ''
      )''');
      await db.execute('''
        INSERT INTO expenses_v6 (id, amount, category, date, note)
        SELECT id, amount, category, date, COALESCE(note, '') FROM expenses
      ''');
      await db.execute('DROP TABLE expenses');
      await db.execute('ALTER TABLE expenses_v6 RENAME TO expenses');
      await db.execute('CREATE INDEX expenses_date ON expenses(date DESC)');
    }
    await db.execute(
      'CREATE INDEX IF NOT EXISTS expenses_category ON expenses(category)',
    );
  }
}
