import 'dart:convert';

import 'package:sqflite/sqflite.dart';

/// Versioned, validated interchange format shared with the Android uploader.
class BackupSnapshot {
  BackupSnapshot._(this.createdAt, this.expenses, this.categories);
  final DateTime createdAt;
  final List<Map<String, Object?>> expenses;
  final List<Map<String, Object?>> categories;
  static const maxBytes = 20 * 1024 * 1024;

  factory BackupSnapshot.parse(String source) {
    if (source.length > maxBytes || utf8.encode(source).length > maxBytes) {
      throw const FormatException('Backup is too large');
    }
    final data = jsonDecode(source);
    if (data is! Map || data['format'] != 'kot_luy_backup' ||
        data['version'] != 1 || data['schemaVersion'] != 2 ||
        data['createdAt'] is! int || data['expenses'] is! List ||
        data['categories'] is! List) {
      throw const FormatException('Unsupported backup');
    }
    int number(dynamic value, int min, int max) {
      if (value is! int || value < min || value > max) {
        throw const FormatException('Invalid number');
      }
      return value;
    }
    String string(dynamic value, {bool empty = false}) {
      if (value is! String || value.length > 100000 ||
          (!empty && value.trim().isEmpty)) {
        throw const FormatException('Invalid text');
      }
      return value;
    }
    final categoryIds = <String>{};
    final categories = <Map<String, Object?>>[];
    for (final row in data['categories']) {
      if (row is! Map) throw const FormatException('Invalid category');
      final id = string(row['id']);
      if (!categoryIds.add(id)) throw const FormatException('Duplicate category');
      categories.add({
        'id': id, 'label': string(row['label']),
        'color_value': number(row['color_value'], 0, 0xffffffff),
        'sort_order': number(row['sort_order'], 0, 1000000),
        'is_custom': number(row['is_custom'], 0, 1),
      });
    }
    if (categories.isEmpty) throw const FormatException('Missing categories');
    final ids = <int>{};
    final expenses = <Map<String, Object?>>[];
    for (final row in data['expenses']) {
      if (row is! Map) throw const FormatException('Invalid expense');
      final id = number(row['id'], 1, 0x7fffffffffffffff);
      if (!ids.add(id)) throw const FormatException('Duplicate expense');
      final category = string(row['category']);
      // Older local records may refer to deleted categories; retain the name.
      expenses.add({
        'id': id, 'title': string(row['title']),
        'amount': number(row['amount'], 1, 999999999999),
        'category': category,
        'date': number(row['date'], -8640000000000000, 8640000000000000),
        'note': string(row['note'], empty: true),
      });
    }
    return BackupSnapshot._(
      DateTime.fromMillisecondsSinceEpoch(
        number(data['createdAt'], 0, 8640000000000000),
      ), expenses, categories,
    );
  }

  static Future<String> capture(DatabaseExecutor db) async => jsonEncode({
    'format': 'kot_luy_backup', 'version': 1, 'schemaVersion': 2,
    'createdAt': DateTime.now().millisecondsSinceEpoch,
    'expenses': await db.query('expenses', orderBy: 'id ASC'),
    'categories': await db.query('categories', orderBy: 'sort_order ASC, id ASC'),
  });

  Future<void> restore(Database db) => db.transaction((txn) async {
    final previous = await capture(txn);
    await txn.execute('CREATE TABLE IF NOT EXISTS restore_safety '
        '(id INTEGER PRIMARY KEY, snapshot TEXT NOT NULL)');
    await txn.insert('restore_safety', {'id': 1, 'snapshot': previous},
        conflictAlgorithm: ConflictAlgorithm.replace);
    await txn.delete('expenses');
    await txn.delete('categories');
    final batch = txn.batch();
    for (final category in categories) {
      batch.insert('categories', category);
    }
    for (final expense in expenses) {
      batch.insert('expenses', expense);
    }
    await batch.commit(noResult: true);
  });

  static Future<BackupSnapshot?> safetyCopy(Database db) async {
    final table = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table' AND name='restore_safety'");
    if (table.isEmpty) return null;
    final rows = await db.query('restore_safety', where: 'id = 1');
    return rows.isEmpty ? null : BackupSnapshot.parse(rows.first['snapshot'] as String);
  }
}
