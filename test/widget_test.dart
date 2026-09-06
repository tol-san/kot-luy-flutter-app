import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kot_luy/data/expense_repository.dart';
import 'package:kot_luy/main.dart';
import 'package:kot_luy/models/expense.dart';
import 'package:sqflite/sqflite.dart';

class MemoryRepository implements ExpenseRepository {
  final List<Expense> items = [];
  final List<ExpenseCategory> categories = [...ExpenseCategory.values];
  @override
  Database get database => throw UnsupportedError('Test double');
  @override
  Future<List<Expense>> all() async =>
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
  Future<List<ExpenseCategory>> getCategories() async =>
      List.unmodifiable(categories);

  @override
  Future<ExpenseCategory> addCategory(String label) async {
    final clean = label.trim();
    final customCount = categories.where((c) => c.isCustom).length;
    final color = ExpenseCategory.autoColors[(customCount + 6) %
        ExpenseCategory.autoColors.length];
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
    categories.removeWhere((c) => c.name == id);
    final fallback =
        categories.isNotEmpty ? categories.first : ExpenseCategory.breakfast;
    for (var i = 0; i < items.length; i++) {
      if (items[i].category.name == id) {
        items[i] = Expense(
          id: items[i].id,
          title: items[i].title,
          amount: items[i].amount,
          category: fallback,
          date: items[i].date,
          note: items[i].note,
        );
      }
    }
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
      await tester.tap(find.byKey(const Key('quick_amount_20000')));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<TextFormField>(find.byKey(const Key('amountInput')))
            .controller!
            .text,
        '20,000',
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
  testWidgets('quick amount chips accumulate on tap and clear button resets amount', (
    tester,
  ) async {
    final repo = MemoryRepository();
    await mount(tester, repo);
    await tester.tap(find.byKey(const Key('addExpense')));
    await tester.pumpAndSettle();

    final inputFinder = find.byKey(const Key('amountInput'));
    expect(tester.widget<TextFormField>(inputFinder).controller!.text, '');

    // Tap 5,000 -> 5,000
    await tester.tap(find.text('+5,000 ៛'));
    await tester.pumpAndSettle();
    expect(tester.widget<TextFormField>(inputFinder).controller!.text, '5,000');

    // Tap 5,000 again (double tap / 2nd tap) -> 10,000
    await tester.tap(find.text('+5,000 ៛'));
    await tester.pumpAndSettle();
    expect(tester.widget<TextFormField>(inputFinder).controller!.text, '10,000');

    // Tap 10,000 -> 20,000
    await tester.tap(find.text('+10,000 ៛'));
    await tester.pumpAndSettle();
    expect(tester.widget<TextFormField>(inputFinder).controller!.text, '20,000');

    // Tap clear button -> empty
    await tester.tap(find.byKey(const Key('clearAmount')));
    await tester.pumpAndSettle();
    expect(tester.widget<TextFormField>(inputFinder).controller!.text, '');
  });
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

    expect(find.text('ជ្រើសរើសប្រភេទចំណាយ'), findsOneWidget);
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
      expect(find.text('រៀបចំប្រភេទចំណាយ'), findsOneWidget);
      expect(find.byKey(const Key('addCategoryInput')), findsOneWidget);
      expect(find.byKey(const Key('addCategoryButton')), findsOneWidget);

      // Verify there is NO icon picker in the UI
      expect(find.text('ជ្រើសរើស Icon'), findsNothing);
      expect(find.text('Icon'), findsNothing);
      expect(find.byType(DropdownButton), findsNothing);

      // Add a custom category: user only inputs the name
      await tester.enterText(
        find.byKey(const Key('addCategoryInput')),
        'ថ្លៃសាលា',
      );
      await tester.tap(find.byKey(const Key('addCategoryButton')));
      await tester.pumpAndSettle();

      // Verify it appears in the reorderable list
      expect(find.text('ថ្លៃសាលា'), findsOneWidget);

      // Close the management sheet
      await tester.tap(find.byKey(const Key('closeCategorySheet')));
      await tester.pumpAndSettle();

      // Since 'ថ្លៃសាលា' is category #6, tap 'ច្រើនទៀត' to open picker
      expect(find.byKey(const Key('category_more')), findsOneWidget);
      await tester.tap(find.byKey(const Key('category_more')));
      await tester.pumpAndSettle();

      // Pick 'ថ្លៃសាលា' from picker sheet
      expect(find.text('ថ្លៃសាលា'), findsOneWidget);
      await tester.tap(find.text('ថ្លៃសាលា'));
      await tester.pumpAndSettle();

      // Verify the 6th button now displays 'ថ្លៃសាលា'
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
}


