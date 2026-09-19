import 'package:clock/clock.dart';
import 'package:flutter/material.dart';

import 'package:kot_luy/models/expense.dart';
import 'package:kot_luy/models/report_period.dart';

/// The period-type chip row + animated sub-period selector (week/month/quarter/semester/year).
///
/// All state is owned by the parent [_PdfExportSheetState] via callbacks.
class PdfPeriodSelector extends StatelessWidget {
  const PdfPeriodSelector({
    super.key,
    required this.periodType,
    required this.selectedYear,
    required this.selectedMonth,
    required this.selectedQuarter,
    required this.selectedSemester,
    required this.selectedWeekStart,
    required this.onPeriodTypeChanged,
    required this.onYearChanged,
    required this.onMonthChanged,
    required this.onQuarterChanged,
    required this.onSemesterChanged,
    required this.onWeekStartChanged,
  });

  final ReportPeriodType periodType;
  final int selectedYear;
  final int selectedMonth;
  final int selectedQuarter;
  final int selectedSemester;
  final DateTime selectedWeekStart;
  final void Function(ReportPeriodType) onPeriodTypeChanged;
  final void Function(int) onYearChanged;
  final void Function(int) onMonthChanged;
  final void Function(int) onQuarterChanged;
  final void Function(int) onSemesterChanged;
  final void Function(DateTime) onWeekStartChanged;

  static const green = Color(0xFF145B32);
  static const ink = Color(0xFF213426);
  static const muted = Color(0xFF5E6B56);
  static const line = Color(0xFFD8DFD0);

  Duration _transitionDuration(BuildContext context) =>
      MediaQuery.disableAnimationsOf(context)
          ? Duration.zero
          : const Duration(milliseconds: 240);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildPeriodTypeRow(context),
        const SizedBox(height: 14),
        _buildSubPeriodSelector(context),
      ],
    );
  }

  Widget _buildPeriodTypeRow(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: ReportPeriodType.values.map((type) {
          final isSelected = periodType == type;
          return Padding(
            padding: const EdgeInsets.only(right: 6),
            child: ChoiceChip(
              key: Key('pdf_period_${type.name}'),
              label: Text(type.label),
              selected: isSelected,
              showCheckmark: false,
              onSelected: (_) => onPeriodTypeChanged(type),
              selectedColor: const Color(0xFFEAF0E1),
              backgroundColor: Colors.white,
              labelStyle: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected ? green : ink,
              ),
              side: BorderSide(
                color: isSelected ? green : line,
                width: isSelected ? 1.4 : 1,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildSubPeriodSelector(BuildContext context) {
    final duration = _transitionDuration(context);
    return AnimatedSize(
      duration: duration,
      curve: Curves.easeInOutCubic,
      alignment: Alignment.topCenter,
      child: AnimatedSwitcher(
        duration: duration,
        switchInCurve: Curves.easeInOutCubic,
        switchOutCurve: Curves.easeInOutCubic,
        layoutBuilder: (currentChild, previousChildren) => Stack(
          alignment: Alignment.topCenter,
          children: [
            for (final child in previousChildren)
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: IgnorePointer(child: ExcludeSemantics(child: child)),
              ),
            ?currentChild,
          ],
        ),
        child: KeyedSubtree(
          key: ValueKey(periodType),
          child: switch (periodType) {
            ReportPeriodType.week => _buildWeekSelector(context, duration),
            ReportPeriodType.month => _buildMonthSelector(context, duration),
            ReportPeriodType.quarter =>
              _buildQuarterSelector(context, duration),
            ReportPeriodType.semester =>
              _buildSemesterSelector(context, duration),
            ReportPeriodType.year => _buildYearDropdown(context),
          },
        ),
      ),
    );
  }

  Widget _buildWeekSelector(BuildContext context, Duration duration) {
    final now = clock.now();
    final startOfToday = DateTime(now.year, now.month, now.day);
    final thisWeekStart = startOfToday.subtract(
      Duration(days: startOfToday.weekday - 1),
    );
    final lastWeekStart = thisWeekStart.subtract(const Duration(days: 7));

    final isThisWeek = selectedWeekStart == thisWeekStart;
    final isLastWeek = selectedWeekStart == lastWeekStart;

    return Row(
      children: [
        Expanded(
          child: OutlinedButton(
            key: const Key('pdf_week_this'),
            style: OutlinedButton.styleFrom(
              backgroundColor:
                  isThisWeek ? const Color(0xFFEAF0E1) : Colors.white,
              side: BorderSide(color: isThisWeek ? green : line),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: () => onWeekStartChanged(thisWeekStart),
            child: Text(
              'សប្ដាហ៍នេះ',
              style: TextStyle(
                color: isThisWeek ? green : ink,
                fontWeight: isThisWeek ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: OutlinedButton(
            key: const Key('pdf_week_last'),
            style: OutlinedButton.styleFrom(
              backgroundColor:
                  isLastWeek ? const Color(0xFFEAF0E1) : Colors.white,
              side: BorderSide(color: isLastWeek ? green : line),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: () => onWeekStartChanged(lastWeekStart),
            child: Text(
              'សប្ដាហ៍មុន',
              style: TextStyle(
                color: isLastWeek ? green : ink,
                fontWeight: isLastWeek ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMonthSelector(BuildContext context, Duration duration) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildYearDropdown(context),
        const SizedBox(height: 10),
        Column(
          children: [
            for (int row = 0; row < 3; row++) ...[
              if (row > 0) const SizedBox(height: 6),
              Row(
                children: [
                  for (int col = 0; col < 4; col++) ...[
                    if (col > 0) const SizedBox(width: 6),
                    Expanded(
                      child: _buildMonthButton(
                        context,
                        row * 4 + col + 1,
                        duration,
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ],
        ),
      ],
    );
  }

  Widget _buildMonthButton(
    BuildContext context,
    int monthNum,
    Duration duration,
  ) {
    final isSelected = selectedMonth == monthNum;
    final monthName = khmerMonths[monthNum - 1];
    return InkWell(
      key: Key('pdf_month_$monthNum'),
      borderRadius: BorderRadius.circular(10),
      onTap: () => onMonthChanged(monthNum),
      child: AnimatedContainer(
        duration: duration,
        curve: Curves.easeInOutCubic,
        padding: const EdgeInsets.symmetric(vertical: 8),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFEAF0E1) : Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? green : line,
            width: isSelected ? 1.4 : 1,
          ),
        ),
        child: Text(
          monthName,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            color: isSelected ? green : ink,
          ),
        ),
      ),
    );
  }

  Widget _buildQuarterSelector(BuildContext context, Duration duration) {
    final quarters = [
      (1, 'ត្រីមាសទី ១ (មករា-មីនា)'),
      (2, 'ត្រីមាសទី ២ (មេសា-មិថុនា)'),
      (3, 'ត្រីមាសទី ៣ (កក្កដា-កញ្ញា)'),
      (4, 'ត្រីមាសទី ៤ (តុលា-ធ្នូ)'),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildYearDropdown(context),
        const SizedBox(height: 8),
        ...quarters.map((q) {
          final isSelected = selectedQuarter == q.$1;
          return Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: InkWell(
              key: Key('pdf_quarter_${q.$1}'),
              borderRadius: BorderRadius.circular(12),
              onTap: () => onQuarterChanged(q.$1),
              child: AnimatedContainer(
                duration: duration,
                curve: Curves.easeInOutCubic,
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: isSelected ? const Color(0xFFEAF0E1) : Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: isSelected ? green : line),
                ),
                child: Row(
                  children: [
                    Icon(
                      isSelected
                          ? Icons.radio_button_checked_rounded
                          : Icons.radio_button_off_rounded,
                      color: isSelected ? green : muted,
                      size: 18,
                    ),
                    const SizedBox(width: 10),
                    Text(
                      q.$2,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight:
                            isSelected ? FontWeight.w700 : FontWeight.w500,
                        color: isSelected ? green : ink,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildSemesterSelector(BuildContext context, Duration duration) {
    final semesters = [
      (1, 'ឆមាសទី ១ (មករា ដល់ មិថុនា)'),
      (2, 'ឆមាសទី ២ (កក្កដា ដល់ ធ្នូ)'),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildYearDropdown(context),
        const SizedBox(height: 8),
        ...semesters.map((s) {
          final isSelected = selectedSemester == s.$1;
          return Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: InkWell(
              key: Key('pdf_semester_${s.$1}'),
              borderRadius: BorderRadius.circular(12),
              onTap: () => onSemesterChanged(s.$1),
              child: AnimatedContainer(
                duration: duration,
                curve: Curves.easeInOutCubic,
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: isSelected ? const Color(0xFFEAF0E1) : Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: isSelected ? green : line),
                ),
                child: Row(
                  children: [
                    Icon(
                      isSelected
                          ? Icons.radio_button_checked_rounded
                          : Icons.radio_button_off_rounded,
                      color: isSelected ? green : muted,
                      size: 18,
                    ),
                    const SizedBox(width: 10),
                    Text(
                      s.$2,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight:
                            isSelected ? FontWeight.w700 : FontWeight.w500,
                        color: isSelected ? green : ink,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildYearDropdown(BuildContext context) {
    final currentYear = clock.now().year;
    final years = [currentYear, currentYear - 1, currentYear - 2];
    return Row(
      children: [
        const Text(
          'ជ្រើសរើសឆ្នាំ៖ ',
          style: TextStyle(fontSize: 12, color: muted),
        ),
        const SizedBox(width: 8),
        ...years.map((y) {
          final isSelected = selectedYear == y;
          return Padding(
            padding: const EdgeInsets.only(right: 6),
            child: ChoiceChip(
              key: Key('pdf_year_$y'),
              label: Text('$y'),
              selected: isSelected,
              showCheckmark: false,
              onSelected: (_) => onYearChanged(y),
              selectedColor: const Color(0xFFEAF0E1),
              backgroundColor: Colors.white,
              labelStyle: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected ? green : ink,
              ),
              side: BorderSide(
                color: isSelected ? green : line,
                width: isSelected ? 1.4 : 1,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          );
        }),
      ],
    );
  }
}
