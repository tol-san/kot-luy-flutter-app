import 'expense.dart';

enum ReportPeriodType {
  week('ប្រចាំសប្ដាហ៍'),
  month('ប្រចាំខែ'),
  quarter('ប្រចាំត្រីមាស'),
  semester('ប្រចាំឆមាស'),
  year('ប្រចាំឆ្នាំ');

  final String label;
  const ReportPeriodType(this.label);
}

enum ReportDetailLevel {
  summary('សង្ខេប'),
  detailed('លម្អិត');

  final String label;
  const ReportDetailLevel(this.label);
}

class ReportPeriodConfig {
  const ReportPeriodConfig({
    required this.periodType,
    required this.year,
    this.month = 1,
    this.quarter = 1,
    this.semester = 1,
    this.weekStart,
  });

  final ReportPeriodType periodType;
  final int year;
  final int month;
  final int quarter;
  final int semester;
  final DateTime? weekStart;

  /// Returns the start [DateTime] (inclusive) for this period.
  DateTime get startDate {
    switch (periodType) {
      case ReportPeriodType.week:
        if (weekStart != null) {
          final d = weekStart!;
          return DateTime(d.year, d.month, d.day);
        }
        final now = DateTime.now();
        final startOfDay = DateTime(now.year, now.month, now.day);
        return startOfDay.subtract(Duration(days: startOfDay.weekday - 1));
      case ReportPeriodType.month:
        return DateTime(year, month, 1);
      case ReportPeriodType.quarter:
        final startMonth = (quarter - 1) * 3 + 1;
        return DateTime(year, startMonth, 1);
      case ReportPeriodType.semester:
        final startMonth = (semester - 1) * 6 + 1;
        return DateTime(year, startMonth, 1);
      case ReportPeriodType.year:
        return DateTime(year, 1, 1);
    }
  }

  /// Returns the end [DateTime] (inclusive) for this period.
  DateTime get endDate {
    switch (periodType) {
      case ReportPeriodType.week:
        return startDate.add(
          const Duration(
            days: 6,
            hours: 23,
            minutes: 59,
            seconds: 59,
            milliseconds: 999,
          ),
        );
      case ReportPeriodType.month:
        final lastDay = DateTime(year, month + 1, 0).day;
        return DateTime(year, month, lastDay, 23, 59, 59, 999);
      case ReportPeriodType.quarter:
        final endMonth = quarter * 3;
        final lastDay = DateTime(year, endMonth + 1, 0).day;
        return DateTime(year, endMonth, lastDay, 23, 59, 59, 999);
      case ReportPeriodType.semester:
        final endMonth = semester * 6;
        final lastDay = DateTime(year, endMonth + 1, 0).day;
        return DateTime(year, endMonth, lastDay, 23, 59, 59, 999);
      case ReportPeriodType.year:
        return DateTime(year, 12, 31, 23, 59, 59, 999);
    }
  }

  /// Checks if [date] falls within this period
  bool contains(DateTime date) {
    return !date.isBefore(startDate) && !date.isAfter(endDate);
  }

  /// Filters a list of expenses
  List<Expense> filterExpenses(List<Expense> expenses) {
    return expenses.where((e) => contains(e.date)).toList()
      ..sort((a, b) => a.date.compareTo(b.date));
  }

  /// Khmer description of this period, e.g. "ខែ កញ្ញា ឆ្នាំ ២០២៦"
  String get khmerPeriodTitle {
    switch (periodType) {
      case ReportPeriodType.week:
        return 'សប្ដាហ៍ (${displayDate(startDate)} ដល់ ${displayDate(endDate)})';
      case ReportPeriodType.month:
        return 'ខែ ${khmerMonths[month - 1]} ឆ្នាំ $year';
      case ReportPeriodType.quarter:
        return 'ត្រីមាសទី $quarter ឆ្នាំ $year';
      case ReportPeriodType.semester:
        return 'ឆមាសទី $semester ឆ្នាំ $year';
      case ReportPeriodType.year:
        return 'ឆ្នាំ $year';
    }
  }

  /// Generate a clean, filesystem-safe filename
  String filename(ReportDetailLevel level) {
    final lvl = level == ReportDetailLevel.summary ? 'summary' : 'detailed';
    final sub = switch (periodType) {
      ReportPeriodType.week =>
        'week_${startDate.year}_${startDate.month}_${startDate.day}',
      ReportPeriodType.month => 'month_${year}_$month',
      ReportPeriodType.quarter => 'quarter${quarter}_$year',
      ReportPeriodType.semester => 'semester${semester}_$year',
      ReportPeriodType.year => 'year_$year',
    };
    return 'kot_loy_${lvl}_$sub.pdf';
  }
}
