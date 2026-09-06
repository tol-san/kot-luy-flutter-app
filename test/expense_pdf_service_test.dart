import 'package:flutter_test/flutter_test.dart';
import 'package:kot_luy/models/expense.dart';
import 'package:kot_luy/models/report_period.dart';
import 'package:kot_luy/pdf/expense_pdf_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ExpensePdfService', () {
    final expenses = [
      Expense(
        id: 1,
        title: 'បាយព្រឹក',
        amount: 12000,
        date: DateTime(2026, 3, 5, 8, 30),
        category: ExpenseCategory.breakfast,
        note: 'បាយព្រឹក',
      ),
      Expense(
        id: 2,
        title: 'ចាក់សាំង',
        amount: 25000,
        date: DateTime(2026, 3, 5, 14, 0),
        category: ExpenseCategory.fuel,
        note: 'ចាក់សាំង',
      ),
    ];

    test('generateReport generates valid PDF bytes for Summary report', () async {
      final config = ReportPeriodConfig(
        periodType: ReportPeriodType.month,
        year: 2026,
        month: 3,
      );

      final pdfBytes = await ExpensePdfService.generateReport(
        expenses: expenses,
        period: config,
        level: ReportDetailLevel.summary,
      );

      expect(pdfBytes, isNotNull);
      expect(pdfBytes.isNotEmpty, isTrue);
      // Valid PDF files begin with '%PDF-'
      final header = String.fromCharCodes(pdfBytes.take(5));
      expect(header, equals('%PDF-'));
    });

    test('generateReport generates valid PDF bytes for Detailed report', () async {
      final config = ReportPeriodConfig(
        periodType: ReportPeriodType.week,
        year: 2026,
        weekStart: DateTime(2026, 3, 2),
      );

      final pdfBytes = await ExpensePdfService.generateReport(
        expenses: expenses,
        period: config,
        level: ReportDetailLevel.detailed,
      );

      expect(pdfBytes, isNotNull);
      expect(pdfBytes.isNotEmpty, isTrue);
      final header = String.fromCharCodes(pdfBytes.take(5));
      expect(header, equals('%PDF-'));
    });

    test('generateReport handles empty expenses gracefully', () async {
      final config = ReportPeriodConfig(
        periodType: ReportPeriodType.year,
        year: 2026,
      );

      final pdfBytes = await ExpensePdfService.generateReport(
        expenses: [],
        period: config,
        level: ReportDetailLevel.summary,
      );

      expect(pdfBytes, isNotNull);
      expect(pdfBytes.isNotEmpty, isTrue);
      final header = String.fromCharCodes(pdfBytes.take(5));
      expect(header, equals('%PDF-'));
    });
  });
}
