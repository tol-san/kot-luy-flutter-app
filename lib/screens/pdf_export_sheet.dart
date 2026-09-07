import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:printing/printing.dart';

import '../data/expense_repository.dart';
import '../models/expense.dart';
import '../models/report_period.dart';
import '../pdf/expense_pdf_service.dart';
import '../pdf/pdf_downloader.dart';

enum _PdfAction { preview, download }

class PdfExportSheet extends StatefulWidget {
  const PdfExportSheet({super.key, required this.repository});
  final ExpenseRepository repository;

  static Future<void> show(
    BuildContext context, {
    required ExpenseRepository repository,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => PdfExportSheet(repository: repository),
    );
  }

  @override
  State<PdfExportSheet> createState() => _PdfExportSheetState();
}

class _PdfExportSheetState extends State<PdfExportSheet> {
  static const green = Color(0xFF145B32);
  static const ink = Color(0xFF213426);
  static const paper = Color(0xFFFAFBF7);
  static const muted = Color(0xFF5E6B56);
  static const line = Color(0xFFD8DFD0);

  List<Expense> _allExpenses = [];
  bool _loading = true;
  _PdfAction? _activeAction;
  bool get _generating => _activeAction != null;

  static const _level = ReportDetailLevel.detailed;
  ReportPeriodType _periodType = ReportPeriodType.month;

  late int _selectedYear;
  late int _selectedMonth;
  late int _selectedQuarter;
  late int _selectedSemester;
  late DateTime _selectedWeekStart;

  @override
  void initState() {
    super.initState();
    final now = clock.now();
    _selectedYear = now.year;
    _selectedMonth = now.month;
    _selectedQuarter = ((now.month - 1) ~/ 3) + 1;
    _selectedSemester = ((now.month - 1) ~/ 6) + 1;
    final startOfToday = DateTime(now.year, now.month, now.day);
    _selectedWeekStart = startOfToday.subtract(
      Duration(days: startOfToday.weekday - 1),
    );
    _loadExpenses();
  }

  Future<void> _loadExpenses() async {
    try {
      final items = await widget.repository.all();
      if (mounted) {
        setState(() {
          _allExpenses = items;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  ReportPeriodConfig get _currentConfig => ReportPeriodConfig(
    periodType: _periodType,
    year: _selectedYear,
    month: _selectedMonth,
    quarter: _selectedQuarter,
    semester: _selectedSemester,
    weekStart: _selectedWeekStart,
  );

  List<Expense> get _filteredExpenses =>
      _currentConfig.filterExpenses(_allExpenses);

  Future<void> _previewAndPrint() async {
    if (_generating) return;
    setState(() => _activeAction = _PdfAction.preview);
    try {
      final config = _currentConfig;
      final pdfBytes = await ExpensePdfService.generateReport(
        expenses: _allExpenses,
        period: config,
        level: _level,
      );
      if (mounted) {
        await Printing.layoutPdf(
          onLayout: (format) async => pdfBytes,
          name: config.filename(_level),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('មិនអាចបង្កើត PDF បានទេ៖ $e')));
      }
    } finally {
      if (mounted) setState(() => _activeAction = null);
    }
  }

  Future<void> _downloadOrShare() async {
    if (_generating) return;
    setState(() => _activeAction = _PdfAction.download);
    try {
      final config = _currentConfig;
      final filename = config.filename(_level);
      final pdfBytes = await ExpensePdfService.generateReport(
        expenses: _allExpenses,
        period: config,
        level: _level,
      );

      final result = await PdfDownloader.saveToDownloads(
        bytes: pdfBytes,
        filename: filename,
      );

      if (mounted) {
        if (result != null) {
          final messenger = ScaffoldMessenger.of(context);
          Navigator.pop(context);
          messenger.hideCurrentSnackBar();
          messenger.showSnackBar(
            SnackBar(
              behavior: SnackBarBehavior.floating,
              duration: const Duration(seconds: 3),
              persist: false,
              content: const Text(
                'បានទាញយក PDF',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              action: SnackBarAction(
                label: 'បើក',
                textColor: const Color(0xFFC4E08F),
                onPressed: () {
                  PdfDownloader.openFile(result.openIdentifier);
                },
              ),
            ),
          );
        } else {
          await Printing.sharePdf(bytes: pdfBytes, filename: filename);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('មានបញ្ហាក្នុងការទាញយក PDF៖ $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _activeAction = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredExpenses;
    final totalAmount = filtered.fold(0, (sum, e) => sum + e.amount);

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.88,
      ),
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      decoration: const BoxDecoration(
        color: paper,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildDragHandle(),
            _buildHeader(),
            if (_loading)
              const LinearProgressIndicator(minHeight: 2, color: green)
            else
              const Divider(height: 1),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildSectionTitle('កាលកំណត់'),
                    const SizedBox(height: 8),
                    _buildPeriodTypeSelector(),
                    const SizedBox(height: 14),
                    _buildSubPeriodSelector(),
                    const SizedBox(height: 16),
                    _buildPreviewCard(filtered.length, totalAmount),
                  ],
                ),
              ),
            ),
            const Divider(height: 1),
            _buildActionButtons(),
          ],
        ),
      ),
    );
  }

  Widget _buildDragHandle() => Center(
    child: Container(
      margin: const EdgeInsets.only(top: 12, bottom: 8),
      width: 36,
      height: 4,
      decoration: BoxDecoration(
        color: line,
        borderRadius: BorderRadius.circular(2),
      ),
    ),
  );

  Widget _buildHeader() => Padding(
    padding: const EdgeInsets.fromLTRB(22, 4, 12, 10),
    child: Row(
      children: [
        const Icon(Icons.picture_as_pdf_rounded, color: green, size: 24),
        const SizedBox(width: 10),
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'ទាញយករបាយការណ៍ PDF',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: ink,
                ),
              ),
              SizedBox(height: 2),
              Text(
                'ជ្រើសរើសកាលកំណត់សម្រាប់របាយការណ៍លម្អិត',
                style: TextStyle(fontSize: 11, color: muted),
              ),
            ],
          ),
        ),
        IconButton(
          key: const Key('closePdfExportSheet'),
          icon: const Icon(Icons.close_rounded, color: muted),
          onPressed: () => Navigator.pop(context),
        ),
      ],
    ),
  );

  Widget _buildSectionTitle(String title) => Text(
    title,
    style: const TextStyle(
      fontSize: 13,
      fontWeight: FontWeight.w700,
      color: ink,
    ),
  );

  Widget _buildPeriodTypeSelector() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: ReportPeriodType.values.map((type) {
          final isSelected = _periodType == type;
          return Padding(
            padding: const EdgeInsets.only(right: 6),
            child: ChoiceChip(
              key: Key('pdf_period_${type.name}'),
              label: Text(type.label),
              selected: isSelected,
              showCheckmark: false,
              onSelected: (_) => setState(() => _periodType = type),
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

  Widget _buildSubPeriodSelector() {
    return AnimatedSize(
      duration: _transitionDuration,
      curve: Curves.easeInOutCubic,
      alignment: Alignment.topCenter,
      child: AnimatedSwitcher(
        duration: _transitionDuration,
        switchInCurve: Curves.easeInOutCubic,
        switchOutCurve: Curves.easeInOutCubic,
        // Size to the new controls while outgoing controls fade away.
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
          key: ValueKey(_periodType),
          child: () {
            switch (_periodType) {
              case ReportPeriodType.week:
                return _buildWeekSelector();
              case ReportPeriodType.month:
                return _buildMonthSelector();
              case ReportPeriodType.quarter:
                return _buildQuarterSelector();
              case ReportPeriodType.semester:
                return _buildSemesterSelector();
              case ReportPeriodType.year:
                return _buildYearSelector();
            }
          }(),
        ),
      ),
    );
  }

  Duration get _transitionDuration => MediaQuery.disableAnimationsOf(context)
      ? Duration.zero
      : const Duration(milliseconds: 240);

  Widget _buildWeekSelector() {
    final now = clock.now();
    final startOfToday = DateTime(now.year, now.month, now.day);
    final thisWeekStart = startOfToday.subtract(
      Duration(days: startOfToday.weekday - 1),
    );
    final lastWeekStart = thisWeekStart.subtract(const Duration(days: 7));

    final isThisWeek = _selectedWeekStart == thisWeekStart;
    final isLastWeek = _selectedWeekStart == lastWeekStart;

    return Row(
      children: [
        Expanded(
          child: OutlinedButton(
            key: const Key('pdf_week_this'),
            style: OutlinedButton.styleFrom(
              backgroundColor: isThisWeek
                  ? const Color(0xFFEAF0E1)
                  : Colors.white,
              side: BorderSide(color: isThisWeek ? green : line),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: () => setState(() => _selectedWeekStart = thisWeekStart),
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
              backgroundColor: isLastWeek
                  ? const Color(0xFFEAF0E1)
                  : Colors.white,
              side: BorderSide(color: isLastWeek ? green : line),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: () => setState(() => _selectedWeekStart = lastWeekStart),
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

  Widget _buildMonthSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildYearDropdown(),
        const SizedBox(height: 10),
        Column(
          children: [
            for (int row = 0; row < 3; row++) ...[
              if (row > 0) const SizedBox(height: 6),
              Row(
                children: [
                  for (int col = 0; col < 4; col++) ...[
                    if (col > 0) const SizedBox(width: 6),
                    Expanded(child: _buildMonthButton(row * 4 + col + 1)),
                  ],
                ],
              ),
            ],
          ],
        ),
      ],
    );
  }

  Widget _buildMonthButton(int monthNum) {
    final isSelected = _selectedMonth == monthNum;
    final monthName = khmerMonths[monthNum - 1];
    return InkWell(
      key: Key('pdf_month_$monthNum'),
      borderRadius: BorderRadius.circular(10),
      onTap: () => setState(() => _selectedMonth = monthNum),
      child: AnimatedContainer(
        duration: _transitionDuration,
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

  Widget _buildQuarterSelector() {
    final quarters = [
      (1, 'ត្រីមាសទី ១ (មករា-មីនា)'),
      (2, 'ត្រីមាសទី ២ (មេសា-មិថុនា)'),
      (3, 'ត្រីមាសទី ៣ (កក្កដា-កញ្ញា)'),
      (4, 'ត្រីមាសទី ៤ (តុលា-ធ្នូ)'),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildYearDropdown(),
        const SizedBox(height: 8),
        ...quarters.map((q) {
          final isSelected = _selectedQuarter == q.$1;
          return Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: InkWell(
              key: Key('pdf_quarter_${q.$1}'),
              borderRadius: BorderRadius.circular(12),
              onTap: () => setState(() => _selectedQuarter = q.$1),
              child: AnimatedContainer(
                duration: _transitionDuration,
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
                        fontWeight: isSelected
                            ? FontWeight.w700
                            : FontWeight.w500,
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

  Widget _buildSemesterSelector() {
    final semesters = [
      (1, 'ឆមាសទី ១ (មករា ដល់ មិថុនា)'),
      (2, 'ឆមាសទី ២ (កក្កដា ដល់ ធ្នូ)'),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildYearDropdown(),
        const SizedBox(height: 8),
        ...semesters.map((s) {
          final isSelected = _selectedSemester == s.$1;
          return Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: InkWell(
              key: Key('pdf_semester_${s.$1}'),
              borderRadius: BorderRadius.circular(12),
              onTap: () => setState(() => _selectedSemester = s.$1),
              child: AnimatedContainer(
                duration: _transitionDuration,
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
                        fontWeight: isSelected
                            ? FontWeight.w700
                            : FontWeight.w500,
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

  Widget _buildYearSelector() {
    return _buildYearDropdown();
  }

  Widget _buildYearDropdown() {
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
          final isSelected = _selectedYear == y;
          return Padding(
            padding: const EdgeInsets.only(right: 6),
            child: ChoiceChip(
              key: Key('pdf_year_$y'),
              label: Text('$y'),
              selected: isSelected,
              showCheckmark: false,
              onSelected: (_) => setState(() => _selectedYear = y),
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

  Widget _buildPreviewCard(int count, int total) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5EB),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: line),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _currentConfig.khmerPeriodTitle,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: ink,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'រកឃើញចំណាយចំនួន $count ប្រតិបត្តិការ • សរុប ${riel(total)}',
                  style: const TextStyle(fontSize: 11, color: muted),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 14),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              key: const Key('previewPdfButton'),
              onPressed: _generating ? null : _previewAndPrint,
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: green),
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              icon: _activeAction == _PdfAction.preview
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: green,
                      ),
                    )
                  : const Icon(Icons.print_outlined, size: 18, color: green),
              label: Text(
                _activeAction == _PdfAction.preview
                    ? 'កំពុងរៀបចំ…'
                    : 'មើល / បោះពុម្ព',
                style: const TextStyle(
                  color: green,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: FilledButton.icon(
              key: const Key('downloadPdfButton'),
              onPressed: _generating ? null : _downloadOrShare,
              style: FilledButton.styleFrom(
                backgroundColor: green,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              icon: _activeAction == _PdfAction.download
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.download_rounded, size: 18),
              label: Text(
                _activeAction == _PdfAction.download
                    ? 'កំពុងទាញយក…'
                    : 'ទាញយក PDF',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
