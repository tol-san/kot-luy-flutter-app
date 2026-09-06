import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kot_loy/data/expense_repository.dart';
import 'package:kot_loy/models/expense.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  sqfliteFfiInit();
  test(
    'SQLite persists Khmer records, exact riel amounts, edits and deletes',
    () async {
      final directory = await Directory.systemTemp.createTemp('kot_loy_test_');
      final path = '${directory.path}/expenses.db';
      var repo = await ExpenseRepository.open(
        factory: databaseFactoryFfi,
        path: path,
      );
      try {
        expect(await repo.all(), isEmpty);
        await repo.save(
          Expense(
            title: 'បាយថ្ងៃត្រង់',
            amount: 12500,
            category: ExpenseCategory.food,
            date: DateTime(2026, 9, 6),
            note: 'ជាមួយមិត្តភក្ដិ',
          ),
        );
        await repo.save(
          Expense(
            title: 'កាហ្វេ',
            amount: 6000,
            category: ExpenseCategory.coffee,
            date: DateTime(2026, 9, 5),
          ),
        );
        await repo.close();
        repo = await ExpenseRepository.open(
          factory: databaseFactoryFfi,
          path: path,
        );
        final saved = await repo.all();
        expect(saved.length, 2);
        expect(saved.first.title, 'បាយថ្ងៃត្រង់');
        expect(saved.first.note, 'ជាមួយមិត្តភក្ដិ');
        expect(saved.fold(0, (sum, e) => sum + e.amount), 18500);
        await repo.save(
          Expense(
            id: saved.first.id,
            title: 'បាយល្ងាច',
            amount: 999999999999,
            category: ExpenseCategory.other,
            date: saved.first.date,
          ),
        );
        expect((await repo.all()).first.amount, 999999999999);
        expect((await repo.all()).first.category, ExpenseCategory.other);
        await repo.delete(saved.first.id!);
        expect((await repo.all()).single.title, 'កាហ្វេ');
        await expectLater(
          repo.save(
            Expense(
              title: 'invalid',
              amount: 0,
              category: ExpenseCategory.food,
              date: DateTime.now(),
            ),
          ),
          throwsArgumentError,
        );
        await expectLater(
          repo.save(
            Expense(
              title: ' ',
              amount: 100,
              category: ExpenseCategory.food,
              date: DateTime.now(),
            ),
          ),
          throwsArgumentError,
        );
      } finally {
        await repo.close();
        await directory.delete(recursive: true);
      }
    },
  );
  test(
    'periods use local calendar boundaries, Monday weeks and year changes',
    () {
      final now = DateTime(2026, 1, 1, 14);
      expect(
        ExpensePeriod.today.contains(DateTime(2026, 1, 1, 23, 59), now),
        isTrue,
      );
      expect(ExpensePeriod.today.contains(DateTime(2026, 1, 2), now), isFalse);
      expect(ExpensePeriod.week.contains(DateTime(2025, 12, 29), now), isTrue);
      expect(ExpensePeriod.week.contains(DateTime(2025, 12, 28), now), isFalse);
      expect(ExpensePeriod.week.contains(DateTime(2026, 1, 5), now), isFalse);
      expect(
        ExpensePeriod.month.contains(DateTime(2025, 12, 31), now),
        isFalse,
      );
      expect(ExpensePeriod.month.contains(DateTime(2026, 1, 31), now), isTrue);
      expect(riel(12500), '12,500 ៛');
    },
  );
}
