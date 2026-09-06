import 'package:flutter/foundation.dart';
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
    final location =
        path ?? p.join(await dbFactory.getDatabasesPath(), 'kot_loy.db');
    final db = await dbFactory.openDatabase(
      location,
      options: OpenDatabaseOptions(
        version: 1,
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
        },
      ),
    );
    return ExpenseRepository(db);
  }

  Future<List<Expense>> all() async => (await database.query(
    'expenses',
    orderBy: 'date DESC, id DESC',
  )).map(Expense.fromMap).toList();
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
