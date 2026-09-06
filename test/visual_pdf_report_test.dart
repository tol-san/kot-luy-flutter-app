import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kot_luy/models/expense.dart';
import 'package:kot_luy/models/report_period.dart';
import 'package:kot_luy/pdf/expense_pdf_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('generate comprehensive Khmer report for visual verification', () async {
    final expenses = [
      Expense(
        id: 1,
        title: 'បាយពេលព្រឹក',
        amount: 15000,
        date: DateTime(2026, 3, 5, 7, 30),
        category: ExpenseCategory.breakfast,
        note: 'បាយសាច់ជ្រូក និងកាហ្វេទឹកដោះគោ (\$3.75)',
      ),
      Expense(
        id: 2,
        title: 'បាយថ្ងៃត្រង់',
        amount: 22000,
        date: DateTime(2026, 3, 5, 12, 15),
        category: ExpenseCategory.lunch,
        note: 'បាយសម្លកកូរជាមួយត្រី និងទឹកក្រូច',
      ),
      Expense(
        id: 3,
        title: 'ចាក់សាំងម៉ូតូ',
        amount: 30000,
        date: DateTime(2026, 3, 5, 14, 0),
        category: ExpenseCategory.fuel,
        note: 'ចាក់សាំងពេញធុងនៅស្ថានីយ៍តេលា',
      ),
      Expense(
        id: 4,
        title: 'កាហ្វេប្រជុំការងារ',
        amount: 18000,
        date: DateTime(2026, 3, 6, 9, 30),
        category: ExpenseCategory.coffee,
        note: 'កាហ្វេប្រជុំជាមួយក្រុមការងារ 2 កែវ',
      ),
      Expense(
        id: 5,
        title: 'បាយល្ងាចគ្រួសារ',
        amount: 80000,
        date: DateTime(2026, 3, 6, 18, 30),
        category: ExpenseCategory.dinner,
        note: 'ជួបជុំញ៉ាំបាយល្ងាចជាមួយគ្រួសារ',
      ),
      Expense(
        id: 6,
        title: 'ប្រភពចំណូល និងចំណាយផ្សេងៗ',
        amount: 900000,
        date: DateTime(2026, 3, 7, 10, 0),
        category: ExpenseCategory(
          name: 'shopping',
          label: 'ប្រភពចំណូល និងទិញទំនិញ',
          icon: Icons.shopping_bag_outlined,
          color: const Color(0xFF658B62),
          background: const Color(0xFFEAF0E1),
          isCustom: true,
        ),
        note: 'ទិញសម្ភារៈប្រើប្រាស់ក្នុងផ្ទះ (\$225.00)',
      ),
    ];

    final period = ReportPeriodConfig(
      periodType: ReportPeriodType.month,
      year: 2026,
      month: 3,
    );

    // 1. Detailed Report
    final detailedBytes = await ExpensePdfService.generateReport(
      expenses: expenses,
      period: period,
      level: ReportDetailLevel.detailed,
    );

    final outDir = Directory('build/visual_reports');
    if (!outDir.existsSync()) outDir.createSync(recursive: true);

    final detailedFile = File('build/visual_reports/report_detailed.pdf');
    await detailedFile.writeAsBytes(detailedBytes);
    expect(detailedBytes.isNotEmpty, isTrue);

    // 2. Summary Report
    final summaryBytes = await ExpensePdfService.generateReport(
      expenses: expenses,
      period: period,
      level: ReportDetailLevel.summary,
    );

    final summaryFile = File('build/visual_reports/report_summary.pdf');
    await summaryFile.writeAsBytes(summaryBytes);
    expect(summaryBytes.isNotEmpty, isTrue);
  });
}
