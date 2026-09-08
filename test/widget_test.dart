import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kot_luy/data/expense_repository.dart';
import 'package:kot_luy/main.dart';
import 'package:kot_luy/models/expense.dart';
import 'package:kot_luy/screens/category_management_sheet.dart';
import 'package:kot_luy/screens/expense_form.dart';
import 'package:sqflite/sqflite.dart';

class MemoryRepository implements ExpenseRepository {
  final List<Expense> items = [];
  final List<ExpenseCategory> categories = [...ExpenseCategory.values];
  final Set<String> archivedIds = {};
  @override
  Database get database => throw UnsupportedError('Test double');
  @override
  Future<List<Expense>> all({List<ExpenseCategory>? categories}) async =>
      [...items]..sort((a, b) => b.date.compareTo(a.date));
  @override
  Future<void> save(Expense expense) async {
    final id = expense.id ?? items.fold(0, (a, e) => e.id! > a ? e.id! : a) + 1;
    items.removeWhere((e) => e.id == id);
    items.add(
      Expense(
        id: id,
        title: expense.title,
        amount: expense.amount,
        category: expense.category,
        date: expense.date,
        note: expense.note,
      ),
    );
  }

  @override
  Future<void> delete(int id) async => items.removeWhere((e) => e.id == id);

  @override
  Future<void> deleteMultiple(List<int> ids) async =>
      items.removeWhere((e) => ids.contains(e.id));

  @override
  Future<List<ExpenseCategory>> getCategories({
    bool includeArchived = false,
  }) async => categories
      .where((c) => includeArchived || !archivedIds.contains(c.name))
      .map(
        (c) => ExpenseCategory(
          name: c.name,
          label: c.label,
          icon: c.icon,
          color: c.color,
          background: c.background,
          isCustom: c.isCustom,
          isArchived: archivedIds.contains(c.name),
        ),
      )
      .toList();

  @override
  Future<ExpenseCategory> addCategory(String label) async {
    final clean = label.trim();
    if (clean.isEmpty) throw ArgumentError('ឈ្មោះមុខចំណាយមិនអាចទទេបានទេ');
    if (categories.any(
      (c) => c.label.trim().toLowerCase() == clean.toLowerCase(),
    )) {
      throw ArgumentError('មុខចំណាយនេះមានរួចហើយ');
    }
    final customCount = categories.where((c) => c.isCustom).length;
    final color = ExpenseCategory
        .autoColors[(customCount + 6) % ExpenseCategory.autoColors.length];
    final id = 'custom_${DateTime.now().millisecondsSinceEpoch}_$customCount';
    final cat = ExpenseCategory(
      name: id,
      label: clean,
      icon: Icons.local_offer_outlined,
      color: color,
      background: ExpenseCategory.autoBackground(color),
      isCustom: true,
    );
    categories.add(cat);
    return cat;
  }

  @override
  Future<void> deleteCategory(String id) async {
    if (await categoryHasExpenses(id)) {
      archivedIds.add(id);
    } else {
      categories.removeWhere((c) => c.name == id);
    }
  }

  @override
  Future<bool> categoryHasExpenses(String id) async =>
      items.any((e) => e.category.name == id);

  @override
  Future<void> restoreCategory(String id) async {
    archivedIds.remove(id);
  }

  @override
  Future<void> reorderCategories(List<String> ids) async {
    final map = {for (final c in categories) c.name: c};
    categories.clear();
    for (final id in ids) {
      if (map.containsKey(id)) categories.add(map[id]!);
    }
  }

  @override
  Future<void> close() async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('used category can be archived and restored from management', (
    tester,
  ) async {
    final repo = MemoryRepository();
    await repo.save(
      Expense(
        title: 'កាហ្វេ',
        amount: 20000,
        category: ExpenseCategory.coffee,
        date: DateTime(2026, 9, 6),
      ),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: CategoryManagementSheet(repository: repo)),
      ),
    );
    await tester.pumpAndSettle();
    final row = find
        .ancestor(
          of: find.byKey(const Key('select_category_coffee')),
          matching: find.byType(AnimatedContainer),
        )
        .first;
    await tester.tap(
      find.descendant(of: row, matching: find.byType(IconButton)),
    );
    await tester.pumpAndSettle();
    expect(find.text('លាក់មុខចំណាយនេះ?'), findsOneWidget);
    await tester.tap(find.text('លាក់'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('select_category_coffee')), findsNothing);
    expect(repo.items.single.amount, 20000);
    expect(repo.items.single.category.name, 'coffee');
    await tester.ensureVisible(find.text('មុខចំណាយដែលបានលាក់ (1)'));
    await tester.tap(find.text('មុខចំណាយដែលបានលាក់ (1)'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('បង្ហាញឡើងវិញ'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('បង្ហាញឡើងវិញ'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('select_category_coffee')), findsOneWidget);
    expect(repo.archivedIds, isEmpty);
  });

  testWidgets(
    'editing archived expense keeps its category after managing choices',
    (tester) async {
      final repo = MemoryRepository();
      await repo.save(
        Expense(
          title: 'កាហ្វេ',
          amount: 20000,
          category: ExpenseCategory.coffee,
          date: DateTime(2026, 9, 6),
        ),
      );
      repo.archivedIds.add('coffee');
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ExpenseForm(repository: repo, expense: repo.items.single),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('category_coffee')), findsNothing);
      await tester.tap(find.byKey(const Key('manageCategoriesButton')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('closeCategorySheet')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('amountInput')), '25000');
      await tester.ensureVisible(find.byKey(const Key('saveExpense')));
      await tester.tap(find.byKey(const Key('saveExpense')));
      await tester.pumpAndSettle();
      expect(repo.items.single.category.name, 'coffee');
      expect(repo.items.single.amount, 25000);
    },
  );
  setUpAll(() async {
    final googleSans = FontLoader('Google Sans')
      ..addFont(rootBundle.load('assets/fonts/GoogleSans-Regular.ttf'))
      ..addFont(rootBundle.load('assets/fonts/GoogleSans-Medium.ttf'))
      ..addFont(rootBundle.load('assets/fonts/GoogleSans-Bold.ttf'));
    await googleSans.load();
    final googleSansKhmer = FontLoader('Google Sans Khmer')
      ..addFont(rootBundle.load('assets/fonts/GoogleSansKhmer-Regular.ttf'))
      ..addFont(rootBundle.load('assets/fonts/GoogleSansKhmer-Medium.ttf'))
      ..addFont(rootBundle.load('assets/fonts/GoogleSansKhmer-Bold.ttf'));
    await googleSansKhmer.load();
    final font = FontLoader('NotoSansKhmer')
      ..addFont(rootBundle.load('assets/fonts/NotoSansKhmer.ttf'));
    await font.load();
    final icons = FontLoader('MaterialIcons')
      ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
    await icons.load();
  });
  Future<void> mount(
    WidgetTester tester,
    MemoryRepository repo, {
    Size size = const Size(390, 844),
    double scale = 1,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = scale;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await tester.pumpWidget(KotLuyApp(repository: repo));
    await tester.pumpAndSettle();
  }

  testWidgets(
    'add validation, save, view detail, edit and delete refresh totals',
    (tester) async {
      final repo = MemoryRepository();
      await mount(tester, repo);
      expect(find.text('0 ៛'), findsOneWidget);
      await tester.tap(find.byKey(const Key('addExpense')));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(const Key('saveExpense')));
      await tester.tap(find.byKey(const Key('saveExpense')));
      await tester.pumpAndSettle();
      expect(repo.items, isEmpty);
      expect(find.text('សូមបញ្ចូលចំនួនប្រាក់លើសពី 0'), findsOneWidget);
      await tester.enterText(find.byKey(const Key('amountInput')), '12500');
      await tester.pumpAndSettle();
      expect(find.text('សូមបញ្ចូលចំនួនប្រាក់លើសពី 0'), findsNothing);
      expect(
        tester
            .widget<TextFormField>(find.byKey(const Key('amountInput')))
            .controller!
            .text,
        '12,500',
      );
      await tester.ensureVisible(find.byKey(const Key('saveExpense')));
      await tester.tap(find.byKey(const Key('saveExpense')));
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();
      expect(repo.items.single.amount, 12500);
      expect(repo.items.single.title, 'បាយពេលព្រឹក');
      expect(find.byKey(const Key('totalAmount')), findsOneWidget);
      expect(
        tester.widget<Text>(find.byKey(const Key('totalAmount'))).data,
        '12,500 ៛',
      );
      final singleId = repo.items.single.id;
      await tester.ensureVisible(find.byKey(Key('expense_item_$singleId')));
      await tester.tap(find.byKey(Key('expense_item_$singleId')));
      await tester.pumpAndSettle();
      expect(find.text('ចំណាយលម្អិត'), findsOneWidget);
      await tester.ensureVisible(find.text('កែប្រែចំណាយ'));
      await tester.tap(find.text('កែប្រែចំណាយ'));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<TextFormField>(find.byKey(const Key('amountInput')))
            .controller!
            .text,
        '12,500',
      );
      await tester.enterText(find.byKey(const Key('amountInput')), '15000');
      await tester.ensureVisible(find.byKey(const Key('saveExpense')));
      await tester.tap(find.byKey(const Key('saveExpense')));
      await tester.pumpAndSettle();
      expect(find.text('15,000 ៛'), findsOneWidget);
      await tester.ensureVisible(find.text('លុបចំណាយ'));
      await tester.tap(find.text('លុបចំណាយ'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('លុប'));
      await tester.pumpAndSettle();
      expect(repo.items, isEmpty);
      expect(
        tester.widget<Text>(find.byKey(const Key('totalAmount'))).data,
        '0 ៛',
      );
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('mobile screens render with sample data', (tester) async {
    await withClock(Clock.fixed(DateTime(2026, 9, 6, 12)), () async {
      final repo = MemoryRepository();
      final now = clock.now();
      final samples = [
        ('បាយថ្ងៃត្រង់', 12000, ExpenseCategory.lunch),
        ('កាហ្វេពេលព្រឹក', 6500, ExpenseCategory.coffee),
        ('ចាក់សាំង', 8000, ExpenseCategory.fuel),
        ('បាយល្ងាច', 18000, ExpenseCategory.dinner),
      ];
      for (var i = 0; i < samples.length; i++) {
        final s = samples[i];
        await repo.save(
          Expense(
            title: s.$1,
            amount: s.$2,
            category: s.$3,
            date: now.subtract(Duration(hours: i)),
            note: 'ចំណាយប្រចាំថ្ងៃ',
          ),
        );
      }
      await mount(tester, repo);
      await tester.runAsync(() async {
        await precacheImage(
          const AssetImage('assets/logo.png'),
          tester.element(find.byType(Scaffold).first),
        );
      });
      await tester.pumpAndSettle();
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('previews/home.png'),
      );
      final firstItemId = repo.items.first.id;
      await tester.ensureVisible(find.byKey(Key('expense_item_$firstItemId')));
      await tester.tap(find.byKey(Key('expense_item_$firstItemId')));
      await tester.pumpAndSettle();
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('previews/detail.png'),
      );
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('addExpense')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('quick_amount_10000')));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<TextFormField>(find.byKey(const Key('amountInput')))
            .controller!
            .text,
        '10,000',
      );
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('previews/add.png'),
      );
      expect(tester.takeException(), isNull);
    });
  });
  testWidgets('small device, large text and keyboard do not overflow', (
    tester,
  ) async {
    await mount(
      tester,
      MemoryRepository(),
      size: const Size(320, 640),
      scale: 1.4,
    );
    expect(tester.takeException(), isNull);
    await tester.tap(find.byKey(const Key('addExpense')));
    await tester.pumpAndSettle();
    tester.view.viewInsets = const FakeViewPadding(bottom: 270);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('saveExpense')));
    expect(tester.takeException(), isNull);
    tester.view.resetViewInsets();
  });
  testWidgets(
    'quick amount chips accumulate on tap and clear button resets amount',
    (tester) async {
      final repo = MemoryRepository();
      await mount(tester, repo);
      await tester.tap(find.byKey(const Key('addExpense')));
      await tester.pumpAndSettle();

      final inputFinder = find.byKey(const Key('amountInput'));
      expect(tester.widget<TextFormField>(inputFinder).controller!.text, '');

      // Tap 5,000 -> 5,000
      await tester.tap(find.text('+5,000 ៛'));
      await tester.pumpAndSettle();
      expect(
        tester.widget<TextFormField>(inputFinder).controller!.text,
        '5,000',
      );

      // Tap 5,000 again (double tap / 2nd tap) -> 10,000
      await tester.tap(find.text('+5,000 ៛'));
      await tester.pumpAndSettle();
      expect(
        tester.widget<TextFormField>(inputFinder).controller!.text,
        '10,000',
      );

      // Tap 10,000 -> 20,000
      await tester.tap(find.text('+10,000 ៛'));
      await tester.pumpAndSettle();
      expect(
        tester.widget<TextFormField>(inputFinder).controller!.text,
        '20,000',
      );

      // Tap clear button -> empty
      await tester.tap(find.byKey(const Key('clearAmount')));
      await tester.pumpAndSettle();
      expect(tester.widget<TextFormField>(inputFinder).controller!.text, '');
    },
  );
  testWidgets('selecting other category shows custom title input', (
    tester,
  ) async {
    final repo = MemoryRepository();
    await mount(tester, repo);
    await tester.tap(find.byKey(const Key('addExpense')));
    await tester.pumpAndSettle();

    // Exactly 5 default categories + 1 'ច្រើនទៀត' button = 6 buttons
    expect(find.byKey(const Key('category_breakfast')), findsOneWidget);
    expect(find.byKey(const Key('category_lunch')), findsOneWidget);
    expect(find.byKey(const Key('category_dinner')), findsOneWidget);
    expect(find.byKey(const Key('category_fuel')), findsOneWidget);
    expect(find.byKey(const Key('category_coffee')), findsOneWidget);
    expect(find.byKey(const Key('category_more')), findsOneWidget);
    expect(find.text('ច្រើនទៀត'), findsOneWidget);

    // 'ផ្សេងៗ' button is removed
    expect(find.byKey(const Key('category_other')), findsNothing);
    expect(find.text('ផ្សេងៗ'), findsNothing);

    // Tapping 'ច្រើនទៀត' opens the category picker sheet
    await tester.tap(find.byKey(const Key('category_more')));
    await tester.pumpAndSettle();

    expect(find.text('ជ្រើសរើសមុខចំណាយ'), findsOneWidget);
    expect(find.byKey(const Key('picker_category_coffee')), findsOneWidget);

    // Select coffee from picker
    await tester.tap(find.byKey(const Key('picker_category_coffee')));
    await tester.pumpAndSettle();

    // Enter amount and save
    await tester.enterText(find.byKey(const Key('amountInput')), '5000');
    await tester.ensureVisible(find.byKey(const Key('saveExpense')));
    await tester.tap(find.byKey(const Key('saveExpense')));
    await tester.pumpAndSettle();

    expect(repo.items.single.category.name, 'coffee');
    expect(repo.items.single.title, 'កាហ្វេ');
    expect(repo.items.single.amount, 5000);
  });

  testWidgets('date and time picker buttons are present in expense form', (
    tester,
  ) async {
    final repo = MemoryRepository();
    await mount(tester, repo);
    await tester.tap(find.byKey(const Key('addExpense')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('datePickerButton')), findsOneWidget);
    expect(find.byKey(const Key('timePickerButton')), findsOneWidget);
  });

  testWidgets('time syncs live with actual clock until user customizes it', (
    tester,
  ) async {
    final repo = MemoryRepository();
    await mount(tester, repo);
    await tester.tap(find.byKey(const Key('addExpense')));
    await tester.pumpAndSettle();

    await tester.pump(const Duration(seconds: 65));
    await tester.enterText(find.byKey(const Key('amountInput')), '5000');
    await tester.ensureVisible(find.byKey(const Key('saveExpense')));
    await tester.tap(find.byKey(const Key('saveExpense')));
    await tester.pumpAndSettle();

    expect(repo.items.isNotEmpty, isTrue);
  });

  testWidgets(
    'user can create custom category by name only (no icon picker) and reorder',
    (tester) async {
      final repo = MemoryRepository();
      await mount(tester, repo);

      // Open Add Expense form
      await tester.tap(find.byKey(const Key('addExpense')));
      await tester.pumpAndSettle();

      // Tap manage categories button
      expect(find.byKey(const Key('manageCategoriesButton')), findsOneWidget);
      await tester.tap(find.byKey(const Key('manageCategoriesButton')));
      await tester.pumpAndSettle();

      // Verify the management sheet is open
      expect(find.text('រៀបចំមុខចំណាយ'), findsOneWidget);
      expect(find.byKey(const Key('addCategoryInput')), findsOneWidget);
      expect(find.byKey(const Key('addCategoryButton')), findsOneWidget);

      // Verify there is NO icon picker in the UI
      expect(find.text('ជ្រើសរើស Icon'), findsNothing);
      expect(find.text('Icon'), findsNothing);
      expect(find.byType(DropdownButton), findsNothing);

      // Verify typing shows suggestions based on already existing names
      await tester.enterText(find.byKey(const Key('addCategoryInput')), 'បាយ');
      await tester.pumpAndSettle();
      expect(find.text('មុខចំណាយដែលមានស្រាប់:'), findsOneWidget);
      expect(
        find.byKey(const Key('categorySuggestion_breakfast')),
        findsOneWidget,
      );
      expect(find.byKey(const Key('categorySuggestion_lunch')), findsOneWidget);
      expect(
        find.byKey(const Key('categorySuggestion_dinner')),
        findsOneWidget,
      );

      // Verify duplicate category cannot be added (e.g. 'កាហ្វេ')
      await tester.enterText(
        find.byKey(const Key('addCategoryInput')),
        'កាហ្វេ',
      );
      await tester.pumpAndSettle();
      expect(
        find.byKey(const Key('categorySuggestion_coffee')),
        findsOneWidget,
      );

      // Verify duplicate category changes button label to 'មានរួចហើយ' and disables it
      expect(find.text('មានរួចហើយ'), findsOneWidget);
      final button = tester.widget<FilledButton>(
        find.byKey(const Key('addCategoryButton')),
      );
      expect(button.onPressed, isNull);
      expect(find.text('រៀបចំមុខចំណាយ'), findsOneWidget);

      // Add a custom category: user only inputs the name
      await tester.enterText(
        find.byKey(const Key('addCategoryInput')),
        'ថ្លៃសាលា',
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('addCategoryButton')));
      await tester.pumpAndSettle();

      // Verify the management sheet is automatically closed
      expect(find.text('រៀបចំមុខចំណាយ'), findsNothing);

      // Verify the 6th button now automatically displays and selects 'ថ្លៃសាលា'
      expect(find.text('ថ្លៃសាលា'), findsOneWidget);

      // Enter amount and save
      await tester.enterText(find.byKey(const Key('amountInput')), '50000');
      await tester.ensureVisible(find.byKey(const Key('saveExpense')));
      await tester.tap(find.byKey(const Key('saveExpense')));
      await tester.pumpAndSettle();

      // Verify expense saved with custom category
      expect(repo.items.length, 1);
      expect(repo.items.first.category.label, 'ថ្លៃសាលា');
      expect(repo.items.first.category.isCustom, isTrue);
      expect(repo.items.first.amount, 50000);
    },
  );

  testWidgets(
    'bulk delete multiple expenses with selection mode, toggle, select all and confirm dialog',
    (tester) async {
      final repo = MemoryRepository();
      final now = DateTime(2026, 9, 6, 10, 0);
      await repo.save(
        Expense(
          id: 1,
          title: 'កាហ្វេ',
          amount: 5000,
          category: ExpenseCategory.coffee,
          date: now,
        ),
      );
      await repo.save(
        Expense(
          id: 2,
          title: 'បាយព្រឹក',
          amount: 10000,
          category: ExpenseCategory.breakfast,
          date: now,
        ),
      );
      await repo.save(
        Expense(
          id: 3,
          title: 'ចាក់សាំង',
          amount: 20000,
          category: ExpenseCategory.fuel,
          date: now,
        ),
      );

      await mount(tester, repo, size: const Size(390, 1200));

      expect(find.byKey(const Key('expense_item_1')), findsOneWidget);
      expect(find.byKey(const Key('expense_item_2')), findsOneWidget);
      expect(find.byKey(const Key('expense_item_3')), findsOneWidget);

      // 1. Long press on an expense to enter selection mode
      await tester.longPress(find.byKey(const Key('expense_item_1')));
      await tester.pumpAndSettle();

      // Verify selection mode is active
      expect(find.text('បានជ្រើសរើស 1'), findsOneWidget);
      expect(
        find.byKey(const Key('deleteSelectedExpensesButton')),
        findsOneWidget,
      );

      // 2. Tap second item to select it as well
      await tester.tap(find.byKey(const Key('expense_item_2')));
      await tester.pumpAndSettle();
      expect(find.text('បានជ្រើសរើស 2'), findsOneWidget);

      // 3. Test Select All button
      await tester.tap(find.byKey(const Key('selectAllButton')));
      await tester.pumpAndSettle();
      expect(find.text('បានជ្រើសរើស 3'), findsOneWidget);

      // 4. Tap Select All again to deselect all
      await tester.tap(find.byKey(const Key('selectAllButton')));
      await tester.pumpAndSettle();
      expect(find.text('ជ្រើសរើសចំណាយ'), findsOneWidget);

      // 5. Select items 1 and 2
      await tester.tap(find.byKey(const Key('expense_item_1')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('expense_item_2')));
      await tester.pumpAndSettle();
      expect(find.text('បានជ្រើសរើស 2'), findsOneWidget);

      // 6. Tap delete button to open confirmation dialog
      await tester.tap(find.byKey(const Key('deleteSelectedExpensesButton')));
      await tester.pumpAndSettle();

      expect(find.text('លុបចំណាយដែលបានជ្រើសរើស?'), findsOneWidget);
      expect(find.text('លុប (2)'), findsOneWidget);

      // Confirm deletion
      await tester.tap(find.byKey(const Key('confirmBulkDeleteButton')));
      await tester.pumpAndSettle();

      // Verify deleted items are removed and remaining item 3 persists
      expect(repo.items.length, 1);
      expect(repo.items.single.id, 3);
      expect(find.byKey(const Key('expense_item_1')), findsNothing);
      expect(find.byKey(const Key('expense_item_2')), findsNothing);
      expect(find.byKey(const Key('expense_item_3')), findsOneWidget);

      // Verify selection mode has exited
      expect(find.text('បញ្ជីចំណាយ'), findsOneWidget);
    },
  );
}
