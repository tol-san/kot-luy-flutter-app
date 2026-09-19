import 'dart:async';

import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:printing/printing.dart';

import 'package:kot_luy/data/expense_repository.dart';
import 'package:kot_luy/globals.dart';
import 'package:kot_luy/models/expense.dart';
import 'package:kot_luy/models/report_period.dart';
import 'package:kot_luy/pdf/expense_pdf_service.dart';
import 'package:kot_luy/pdf/pdf_downloader.dart';
import 'package:kot_luy/widgets/pdf/pdf_period_selector.dart';
import 'package:kot_luy/widgets/pdf/pdf_preview_card.dart';

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
      final config = _currentConfig;
      // ✅ Filter ក្នុង SQL — load តែ period ដែលជ្រើស ជំនួស load ទាំងអស់
      final items = await widget.repository.all(
        fromInclusive: config.startDate,
        // endDate inclusive → add 1ms to make toExclusive
        toExclusive: config.endDate.add(const Duration(milliseconds: 1)),
      );
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

  // ✅ _allExpenses ត្រូវ filter ក្នុង SQL រួចហើយ — return ដោយផ្ទាល់
  List<Expense> get _filteredExpenses => _allExpenses;

  /// Reload from DB with new period filter ពេល user ផ្លាស់ប្ដូរ period type / sub-period
  Future<void> _reloadForPeriod() async {
    setState(() => _loading = true);
    await _loadExpenses();
  }

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
        rootMessengerKey.currentState
            ?.showSnackBar(SnackBar(content: Text('មិនអាចបង្កើត PDF បានទេ៖ $e')));
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
        rootMessengerKey.currentState?.showSnackBar(
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
                    PdfPeriodSelector(
                      periodType: _periodType,
                      selectedYear: _selectedYear,
                      selectedMonth: _selectedMonth,
                      selectedQuarter: _selectedQuarter,
                      selectedSemester: _selectedSemester,
                      selectedWeekStart: _selectedWeekStart,
                      onPeriodTypeChanged: (type) {
                        setState(() => _periodType = type);
                        unawaited(_reloadForPeriod());
                      },
                      onYearChanged: (y) {
                        setState(() => _selectedYear = y);
                        unawaited(_reloadForPeriod());
                      },
                      onMonthChanged: (m) {
                        setState(() => _selectedMonth = m);
                        unawaited(_reloadForPeriod());
                      },
                      onQuarterChanged: (q) {
                        setState(() => _selectedQuarter = q);
                        unawaited(_reloadForPeriod());
                      },
                      onSemesterChanged: (s) {
                        setState(() => _selectedSemester = s);
                        unawaited(_reloadForPeriod());
                      },
                      onWeekStartChanged: (d) {
                        setState(() => _selectedWeekStart = d);
                        unawaited(_reloadForPeriod());
                      },
                    ),
                    const SizedBox(height: 16),
                    PdfPreviewCard(
                      periodTitle: _currentConfig.khmerPeriodTitle,
                      count: filtered.length,
                      total: totalAmount,
                    ),
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
                _activeAction == _PdfAction.preview ? 'កំពុងរៀបចំ…' : 'មើល / បោះពុម្ព',
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
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
