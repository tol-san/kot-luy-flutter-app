import 'package:flutter_test/flutter_test.dart';
import 'package:kot_luy/models/expense.dart';
import 'package:kot_luy/models/report_period.dart';

void main() {
  group('ReportPeriodConfig date calculations & labels', () {
    test('Week period range and label', () {
      final weekStart = DateTime(2026, 3, 2); // Monday
      final config = ReportPeriodConfig(
        periodType: ReportPeriodType.week,
        year: 2026,
        weekStart: weekStart,
      );

      expect(config.startDate, DateTime(2026, 3, 2, 0, 0, 0));
      expect(config.endDate, DateTime(2026, 3, 8, 23, 59, 59, 999));
      expect(config.khmerPeriodTitle, contains('សប្ដាហ៍'));
      expect(
        config.filename(ReportDetailLevel.summary),
        startsWith('kot_loy_summary_week_'),
      );
      expect(
        config.filename(ReportDetailLevel.detailed),
        startsWith('kot_loy_detailed_week_'),
      );
    });

    test('Month period range and label', () {
      final config = ReportPeriodConfig(
        periodType: ReportPeriodType.month,
        year: 2026,
        month: 2, // Feb 2026 has 28 days
      );

      expect(config.startDate, DateTime(2026, 2, 1, 0, 0, 0));
      expect(config.endDate, DateTime(2026, 2, 28, 23, 59, 59, 999));
      expect(config.khmerPeriodTitle, 'ខែ កុម្ភៈ ឆ្នាំ 2026');
      expect(
        config.filename(ReportDetailLevel.summary),
        'kot_loy_summary_month_2026_2.pdf',
      );
    });

    test('Quarter period range and label (Q1, Q2, Q3, Q4)', () {
      final q1 = ReportPeriodConfig(
        periodType: ReportPeriodType.quarter,
        year: 2026,
        quarter: 1,
      );
      expect(q1.startDate, DateTime(2026, 1, 1, 0, 0, 0));
      expect(q1.endDate, DateTime(2026, 3, 31, 23, 59, 59, 999));
      expect(q1.khmerPeriodTitle, 'ត្រីមាសទី 1 ឆ្នាំ 2026');
      expect(
        q1.filename(ReportDetailLevel.summary),
        'kot_loy_summary_quarter1_2026.pdf',
      );

      final q4 = ReportPeriodConfig(
        periodType: ReportPeriodType.quarter,
        year: 2026,
        quarter: 4,
      );
      expect(q4.startDate, DateTime(2026, 10, 1, 0, 0, 0));
      expect(q4.endDate, DateTime(2026, 12, 31, 23, 59, 59, 999));
      expect(q4.khmerPeriodTitle, 'ត្រីមាសទី 4 ឆ្នាំ 2026');
      expect(
        q4.filename(ReportDetailLevel.detailed),
        'kot_loy_detailed_quarter4_2026.pdf',
      );
    });

    test('Semester period range and label (S1, S2)', () {
      final s1 = ReportPeriodConfig(
        periodType: ReportPeriodType.semester,
        year: 2026,
        semester: 1,
      );
      expect(s1.startDate, DateTime(2026, 1, 1, 0, 0, 0));
      expect(s1.endDate, DateTime(2026, 6, 30, 23, 59, 59, 999));
      expect(s1.khmerPeriodTitle, 'ឆមាសទី 1 ឆ្នាំ 2026');
      expect(
        s1.filename(ReportDetailLevel.summary),
        'kot_loy_summary_semester1_2026.pdf',
      );

      final s2 = ReportPeriodConfig(
        periodType: ReportPeriodType.semester,
        year: 2026,
        semester: 2,
      );
      expect(s2.startDate, DateTime(2026, 7, 1, 0, 0, 0));
      expect(s2.endDate, DateTime(2026, 12, 31, 23, 59, 59, 999));
      expect(s2.khmerPeriodTitle, 'ឆមាសទី 2 ឆ្នាំ 2026');
      expect(
        s2.filename(ReportDetailLevel.detailed),
        'kot_loy_detailed_semester2_2026.pdf',
      );
    });

    test('Year period range and label', () {
      final config = ReportPeriodConfig(
        periodType: ReportPeriodType.year,
        year: 2026,
      );

      expect(config.startDate, DateTime(2026, 1, 1, 0, 0, 0));
      expect(config.endDate, DateTime(2026, 12, 31, 23, 59, 59, 999));
      expect(config.khmerPeriodTitle, 'ឆ្នាំ 2026');
      expect(
        config.filename(ReportDetailLevel.detailed),
        'kot_loy_detailed_year_2026.pdf',
      );
    });

    test('filterExpenses correctly filters in-range and out-of-range items', () {
      final config = ReportPeriodConfig(
        periodType: ReportPeriodType.month,
        year: 2026,
        month: 5,
      );

      final expenses = [
        Expense(
          id: 1,
          title: 'អាហារ',
          amount: 5000,
          date: DateTime(2026, 4, 30, 23, 59),
          category: ExpenseCategory.breakfast,
        ),
        Expense(
          id: 2,
          title: 'បាយព្រឹក',
          amount: 8000,
          date: DateTime(2026, 5, 1, 0, 1),
          category: ExpenseCategory.breakfast,
        ),
        Expense(
          id: 3,
          title: 'ចាក់សាំង',
          amount: 15000,
          date: DateTime(2026, 5, 20, 12, 0),
          category: ExpenseCategory.fuel,
        ),
        Expense(
          id: 4,
          title: 'កាហ្វេ',
          amount: 20000,
          date: DateTime(2026, 6, 1, 0, 0),
          category: ExpenseCategory.coffee,
        ),
      ];

      final filtered = config.filterExpenses(expenses);
      expect(filtered.map((e) => e.id), [2, 3]);
    });
  });
}
