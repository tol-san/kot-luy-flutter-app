import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';

import '../models/expense.dart';

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
        version: 2,
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
        },
      ),
    );
    // Purge deprecated 'other' if present and reassign any existing expenses
    try {
      await db.transaction((txn) async {
        final remaining = await txn.query(
          'categories',
          where: "id != 'other'",
          orderBy: 'sort_order ASC',
          limit: 1,
        );
        if (remaining.isNotEmpty) {
          final fallbackId = remaining.first['id'] as String;
          await txn.update(
            'expenses',
            {'category': fallbackId},
            where: "category = 'other'",
          );
        }
        await txn.delete('categories', where: "id = 'other'");
      });
    } catch (_) {}
    return ExpenseRepository(db);
  }

  static Future<void> _createCategoriesTable(DatabaseExecutor db) async {
    await db.execute('''CREATE TABLE IF NOT EXISTS categories (
      id TEXT PRIMARY KEY,
      label TEXT NOT NULL,
      color_value INTEGER NOT NULL,
      sort_order INTEGER NOT NULL,
      is_custom INTEGER NOT NULL DEFAULT 0
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

  Future<List<ExpenseCategory>> getCategories() async {
    final rows = await database.query('categories', orderBy: 'sort_order ASC');
    if (rows.isEmpty) {
      await _createCategoriesTable(database);
      return ExpenseCategory.values;
    }
    return rows.map((r) {
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
      );
    }).toList();
  }

  Future<ExpenseCategory> addCategory(String label) async {
    final clean = label.trim();
    if (clean.isEmpty) throw ArgumentError('Category label cannot be empty');
    final current = await getCategories();
    final customCount = current.where((c) => c.isCustom).length;
    final color =
        ExpenseCategory.autoColors[(customCount + 5) %
            ExpenseCategory.autoColors.length];
    final id = 'custom_${DateTime.now().millisecondsSinceEpoch}';
    final nextOrder = current.length;

    await database.insert('categories', {
      'id': id,
      'label': clean,
      'color_value': color.toARGB32(),
      'sort_order': nextOrder,
      'is_custom': 1,
    });

    return ExpenseCategory(
      name: id,
      label: clean,
      icon: Icons.local_offer_outlined,
      color: color,
      background: ExpenseCategory.autoBackground(color),
      isCustom: true,
    );
  }

  Future<void> deleteCategory(String id) async {
    await database.transaction((txn) async {
      final remaining = await txn.query(
        'categories',
        where: 'id != ?',
        whereArgs: [id],
        orderBy: 'sort_order ASC',
        limit: 1,
      );
      if (remaining.isNotEmpty) {
        final fallbackId = remaining.first['id'] as String;
        await txn.update(
          'expenses',
          {'category': fallbackId},
          where: 'category = ?',
          whereArgs: [id],
        );
      }
      await txn.delete('categories', where: 'id = ?', whereArgs: [id]);
    });
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
  }

  Future<List<Expense>> all() async {
    final categories = await getCategories();
    final rows = await database.query('expenses', orderBy: 'date DESC, id DESC');
    return rows.map((r) => Expense.fromMap(r, categories)).toList();
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
  }

  Future<void> delete(int id) async {
    await database.delete('expenses', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> close() => database.close();
}
