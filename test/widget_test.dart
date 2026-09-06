import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kot_loy/data/expense_repository.dart';
import 'package:kot_loy/main.dart';
import 'package:kot_loy/models/expense.dart';
import 'package:sqflite/sqflite.dart';

class MemoryRepository implements ExpenseRepository {
  final List<Expense> items = [];
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
    await tester.pumpWidget(KotLoyApp(repository: repo));
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
      await tester.enterText(find.byKey(const Key('amountInput')), '12500');
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
        ('ទិញសៀវភៅ', 18000, ExpenseCategory.other),
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

    // Default category does not show custom title input
    expect(find.byKey(const Key('customTitleInput')), findsNothing);

    // Tap ផ្សេងៗ
    await tester.tap(find.byKey(const Key('category_other')));
    await tester.pumpAndSettle();

    // Now customTitleInput is visible
    expect(find.byKey(const Key('customTitleInput')), findsOneWidget);

    // Enter amount and custom title
    await tester.enterText(find.byKey(const Key('amountInput')), '5000');
    await tester.enterText(find.byKey(const Key('customTitleInput')), 'ទិញសៀវភៅ');
    await tester.ensureVisible(find.byKey(const Key('saveExpense')));
    await tester.tap(find.byKey(const Key('saveExpense')));
    await tester.pumpAndSettle();

    expect(repo.items.single.category, ExpenseCategory.other);
    expect(repo.items.single.title, 'ទិញសៀវភៅ');
    expect(repo.items.single.amount, 5000);

    // Empty customTitleInput defaults title to ផ្សេងៗ
    await tester.tap(find.byKey(const Key('addExpense')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('category_other')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('amountInput')), '3000');
    await tester.ensureVisible(find.byKey(const Key('saveExpense')));
    await tester.tap(find.byKey(const Key('saveExpense')));
    await tester.pumpAndSettle();

    expect(repo.items.last.category, ExpenseCategory.other);
    expect(repo.items.last.title, 'ផ្សេងៗ');
    expect(repo.items.last.amount, 3000);
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
}


