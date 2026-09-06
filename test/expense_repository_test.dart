import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kot_luy/data/expense_repository.dart';
import 'package:kot_luy/models/expense.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  sqfliteFfiInit();
  test(
    'SQLite persists Khmer records, exact riel amounts, edits and deletes',
    () async {
      final directory = await Directory.systemTemp.createTemp('kot_luy_test_');
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
            category: ExpenseCategory.lunch,
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
              category: ExpenseCategory.lunch,
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
              category: ExpenseCategory.lunch,
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
      expect(formatTime(DateTime(2026, 9, 6, 16, 50)), '4:50 PM');
      expect(formatTime(DateTime(2026, 9, 6, 9, 5)), '9:05 AM');
      expect(formatTime(DateTime(2026, 9, 6, 0, 15)), '12:15 AM');
      expect(formatTime(DateTime(2026, 9, 6, 12, 0)), '12:00 PM');
    },
  );

  test(
    'categories seed defaults, create custom with auto color, reorder and delete',
    () async {
      final directory = await Directory.systemTemp.createTemp('kot_luy_cat_test_');
      final path = '${directory.path}/expenses.db';
      var repo = await ExpenseRepository.open(
        factory: databaseFactoryFfi,
        path: path,
      );
      try {
        // 1. Initial seed check (5 default categories)
        final initialCats = await repo.getCategories();
        expect(initialCats.length, 5);
        expect(initialCats.map((c) => c.name).toList(), [
          'breakfast',
          'lunch',
          'dinner',
          'fuel',
          'coffee',
        ]);

        // 2. Add custom category (only label provided, color is auto)
        final customCat = await repo.addCategory('ថ្លៃផ្ទះ');
        expect(customCat.label, 'ថ្លៃផ្ទះ');
        expect(customCat.isCustom, isTrue);
        expect(customCat.color, isNotNull);

        final updatedCats = await repo.getCategories();
        expect(updatedCats.length, 6);
        expect(updatedCats.last.label, 'ថ្លៃផ្ទះ');

        // 3. Reorder categories (move custom to first)
        final newOrder = [
          customCat.name,
          ...initialCats.map((c) => c.name),
        ];
        await repo.reorderCategories(newOrder);

        // Reopen database to verify persistence of reordering
        await repo.close();
        repo = await ExpenseRepository.open(
          factory: databaseFactoryFfi,
          path: path,
        );

        final reordered = await repo.getCategories();
        expect(reordered.first.name, customCat.name);
        expect(reordered.first.label, 'ថ្លៃផ្ទះ');

        // 4. Save expense with custom category
        await repo.save(
          Expense(
            title: 'បង់ថ្លៃផ្ទះប្រចាំខែ',
            amount: 200000,
            category: customCat,
            date: DateTime(2026, 9, 6),
          ),
        );
        final expenses = await repo.all();
        expect(expenses.single.category.name, customCat.name);
        expect(expenses.single.category.label, 'ថ្លៃផ្ទះ');

        // 5. Delete category -> expense reassigned to first remaining category
        await repo.deleteCategory(customCat.name);
        final catsAfterDelete = await repo.getCategories();
        expect(catsAfterDelete.length, 5);
        expect(catsAfterDelete.any((c) => c.name == customCat.name), isFalse);

        final expensesAfterDelete = await repo.all();
        expect(
          expensesAfterDelete.single.category.name,
          catsAfterDelete.first.name,
        );

        // 6. Any category (including defaults like coffee) can be deleted
        await repo.deleteCategory('coffee');
        final catsAfterCoffeeDelete = await repo.getCategories();
        expect(catsAfterCoffeeDelete.length, 4);
        expect(catsAfterCoffeeDelete.any((c) => c.name == 'coffee'), isFalse);

        // 7. Blank category name rejected
        await expectLater(
          repo.addCategory('   '),
          throwsArgumentError,
        );

        // 8. Duplicate category rejected (case and trim insensitive)
        await expectLater(
          repo.addCategory('បាយថ្ងៃត្រង់'),
          throwsArgumentError,
        );
        await expectLater(
          repo.addCategory('  បាយថ្ងៃត្រង់  '),
          throwsArgumentError,
        );

        // 9. Automatic deduplication of existing duplicate categories
        await repo.database.insert('categories', {
          'id': 'custom_duplicate_test',
          'label': 'បាយថ្ងៃត្រង់',
          'color_value': 0xFF123456,
          'sort_order': 99,
          'is_custom': 1,
        });
        final catsWithDedup = await repo.getCategories();
        final lunchMatches = catsWithDedup.where((c) => c.label == 'បាយថ្ងៃត្រង់');
        expect(lunchMatches.length, 1);
      } finally {
        await repo.close();
        await directory.delete(recursive: true);
      }
    },
  );

  test(
    'deleteMultiple deletes multiple records in SQLite transaction',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'kot_luy_test_delete_multi_',
      );
      final path = '${directory.path}/expenses.db';
      final repo = await ExpenseRepository.open(
        factory: databaseFactoryFfi,
        path: path,
      );
      try {
        await repo.save(
          Expense(
            title: 'A',
            amount: 1000,
            category: ExpenseCategory.breakfast,
            date: DateTime(2026, 9, 6),
          ),
        );
        await repo.save(
          Expense(
            title: 'B',
            amount: 2000,
            category: ExpenseCategory.lunch,
            date: DateTime(2026, 9, 6),
          ),
        );
        await repo.save(
          Expense(
            title: 'C',
            amount: 3000,
            category: ExpenseCategory.dinner,
            date: DateTime(2026, 9, 6),
          ),
        );

        final all = await repo.all();
        expect(all.length, 3);
        final idsToDelete = [all[0].id!, all[1].id!];
        await repo.deleteMultiple(idsToDelete);

        final remaining = await repo.all();
        expect(remaining.length, 1);
        expect(remaining.single.id, all[2].id);
      } finally {
        await repo.close();
        await directory.delete(recursive: true);
      }
    },
  );
}

