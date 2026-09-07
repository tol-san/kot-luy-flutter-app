import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kot_luy/data/expense_repository.dart';
import 'package:kot_luy/models/expense.dart';
import 'package:kot_luy/pdf/pdf_downloader.dart';
import 'package:kot_luy/screens/pdf_export_sheet.dart';

class FakeExpenseRepository extends Fake implements ExpenseRepository {
  FakeExpenseRepository(this._expenses);
  final List<Expense> _expenses;

  @override
  Future<List<Expense>> all({List<ExpenseCategory>? categories}) async => _expenses;

  @override
  Future<List<ExpenseCategory>> getCategories() async => ExpenseCategory.values;
}

void main() {
  testWidgets('PdfExportSheet displays options and toggles periods', (
    tester,
  ) async {
    final now = DateTime.now();
    final expenses = [
      Expense(
        id: 1,
        title: 'បាយព្រឹក',
        amount: 10000,
        category: ExpenseCategory.breakfast,
        date: now,
      ),
      Expense(
        id: 2,
        title: 'កាហ្វេ',
        amount: 6000,
        category: ExpenseCategory.coffee,
        date: now,
      ),
    ];

    final repo = FakeExpenseRepository(expenses);

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [Locale('km'), Locale('en')],
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => PdfExportSheet.show(context, repository: repo),
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );

    // Open sheet
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    // Verify Title and Formats
    expect(find.text('ទាញយករបាយការណ៍ PDF'), findsOneWidget);
    expect(find.text('សង្ខេប'), findsOneWidget);
    expect(find.text('លម្អិត'), findsOneWidget);

    // Verify Periods are present with full labels
    expect(find.text('ប្រចាំសប្ដាហ៍'), findsOneWidget);
    expect(find.text('ប្រចាំខែ'), findsOneWidget);
    expect(find.text('ប្រចាំត្រីមាស'), findsOneWidget);
    expect(find.text('ប្រចាំឆមាស'), findsOneWidget);
    expect(find.text('ប្រចាំឆ្នាំ'), findsOneWidget);

    // Tap on 'ប្រចាំត្រីមាស' (Quarter)
    await tester.ensureVisible(find.text('ប្រចាំត្រីមាស'));
    await tester.tap(find.text('ប្រចាំត្រីមាស'));
    await tester.pumpAndSettle();
    expect(find.text('ត្រីមាសទី ១ (មករា-មីនា)'), findsOneWidget);
    expect(find.text('ត្រីមាសទី ២ (មេសា-មិថុនា)'), findsOneWidget);
    expect(find.text('ត្រីមាសទី ៣ (កក្កដា-កញ្ញា)'), findsOneWidget);
    expect(find.text('ត្រីមាសទី ៤ (តុលា-ធ្នូ)'), findsOneWidget);

    // Tap on 'ប្រចាំឆមាស' (Semester)
    await tester.ensureVisible(find.text('ប្រចាំឆមាស'));
    await tester.tap(find.text('ប្រចាំឆមាស'));
    await tester.pumpAndSettle();
    expect(find.text('ឆមាសទី ១ (មករា ដល់ មិថុនា)'), findsOneWidget);
    expect(find.text('ឆមាសទី ២ (កក្កដា ដល់ ធ្នូ)'), findsOneWidget);

    // Tap on 'ប្រចាំសប្ដាហ៍' (Week)
    await tester.ensureVisible(find.text('ប្រចាំសប្ដាហ៍'));
    await tester.tap(find.text('ប្រចាំសប្ដាហ៍'));
    await tester.pumpAndSettle();
    expect(find.text('សប្ដាហ៍នេះ'), findsOneWidget);
    expect(find.text('សប្ដាហ៍មុន'), findsOneWidget);

    // Tap on 'ប្រចាំខែ' (Month) and verify stable 4x3 month grid
    await tester.ensureVisible(find.text('ប្រចាំខែ'));
    await tester.tap(find.text('ប្រចាំខែ'));
    await tester.pumpAndSettle();
    expect(find.text('ជ្រើសរើសឆ្នាំ៖ '), findsOneWidget);
    // Verify all 12 month buttons are visible
    for (var m = 1; m <= 12; m++) {
      expect(find.byKey(Key('pdf_month_$m')), findsOneWidget);
    }
    // Tap month 9 (កញ្ញា) and month 12 (ធ្នូ)
    await tester.ensureVisible(find.byKey(const Key('pdf_month_9')));
    await tester.tap(find.byKey(const Key('pdf_month_9')));
    await tester.pumpAndSettle();
    expect(find.text('កញ្ញា'), findsOneWidget);

    await tester.ensureVisible(find.byKey(const Key('pdf_month_12')));
    await tester.tap(find.byKey(const Key('pdf_month_12')));
    await tester.pumpAndSettle();
    expect(find.text('ធ្នូ'), findsOneWidget);

    // Action buttons exist
    expect(find.text('មើល / បោះពុម្ព'), findsOneWidget);
    expect(find.text('ទាញយក PDF'), findsOneWidget);
  });

  testWidgets('PdfExportSheet downloads PDF directly and shows Open action', (
    tester,
  ) async {
    final now = DateTime.now();
    final expenses = [
      Expense(
        id: 1,
        title: 'កាហ្វេ',
        amount: 6000,
        category: ExpenseCategory.coffee,
        date: now,
      ),
    ];

    final repo = FakeExpenseRepository(expenses);
    String? savedFilename;
    String? openedTarget;

    PdfDownloader.saveOverride = (bytes, filename) async {
      savedFilename = filename;
      return PdfDownloadResult(
        displayPath: 'Downloads/$filename',
        openIdentifier: 'content://downloads/$filename',
      );
    };

    PdfDownloader.openOverride = (openIdentifier) async {
      openedTarget = openIdentifier;
      return true;
    };

    addTearDown(() {
      PdfDownloader.saveOverride = null;
      PdfDownloader.openOverride = null;
    });

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [Locale('km'), Locale('en')],
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => PdfExportSheet.show(context, repository: repo),
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    // Tap download PDF button
    await tester.tap(find.byKey(const Key('downloadPdfButton')));
    await tester.pumpAndSettle();

    // Verify saveOverride was called with pdf filename
    expect(savedFilename, isNotNull);
    expect(savedFilename!.endsWith('.pdf'), isTrue);

    // Verify SnackBar appears with download message and 'បើក' button
    expect(
      find.text('បានទាញយកឯកសារ PDF ទៅកាន់ Downloads/$savedFilename'),
      findsOneWidget,
    );
    expect(find.text('បើក'), findsOneWidget);

    // Tap 'បើក'
    await tester.tap(find.text('បើក'));
    await tester.pumpAndSettle();

    expect(openedTarget, equals('content://downloads/$savedFilename'));
  });
}
