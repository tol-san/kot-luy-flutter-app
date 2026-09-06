import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../models/expense.dart';
import '../models/report_period.dart';

class ExpensePdfService {
  /// Builds PDF byte data for the given [expenses], [period], and [level].
  static Future<Uint8List> generateReport({
    required List<Expense> expenses,
    required ReportPeriodConfig period,
    required ReportDetailLevel level,
    pw.Font? regularFont,
    pw.Font? boldFont,
  }) async {
    // 1. Load fonts if not provided (allowing test injection)
    final baseFont = regularFont ??
        pw.Font.ttf(
          await rootBundle.load('assets/fonts/GoogleSansKhmer-Regular.ttf'),
        );
    final headerFont = boldFont ??
        pw.Font.ttf(
          await rootBundle.load('assets/fonts/GoogleSansKhmer-Bold.ttf'),
        );
    final fallbackFont = regularFont != null
        ? null
        : pw.Font.ttf(await rootBundle.load('assets/fonts/NotoSansKhmer.ttf'));

    final theme = pw.ThemeData.withFont(
      base: baseFont,
      bold: headerFont,
      fontFallback: fallbackFont != null ? [fallbackFont] : const [],
    );

    final pdf = pw.Document(theme: theme);

    // 2. Filter expenses for this period
    final filtered = period.filterExpenses(expenses);
    final totalAmount = filtered.fold(0, (sum, e) => sum + e.amount);
    final totalCount = filtered.length;

    // 3. Aggregate totals by category
    final categoryMap = <String, ({String label, int count, int total})>{};
    for (final e in filtered) {
      final key = e.category.label;
      final existing = categoryMap[key];
      if (existing != null) {
        categoryMap[key] = (
          label: key,
          count: existing.count + 1,
          total: existing.total + e.amount,
        );
      } else {
        categoryMap[key] = (label: key, count: 1, total: e.amount);
      }
    }
    final sortedCategories = categoryMap.values.toList()
      ..sort((a, b) => b.total.compareTo(a.total));

    // Brand colors
    final primaryColor = PdfColor.fromHex('#145B32');
    final secondaryColor = PdfColor.fromHex('#EAF0E1');
    final darkInk = PdfColor.fromHex('#213426');
    final mutedText = PdfColor.fromHex('#5E6B56');
    final borderColor = PdfColor.fromHex('#D8DFD0');

    final isDetailed = level == ReportDetailLevel.detailed;
    final reportTitleKhmer = isDetailed
        ? 'របាយការណ៍ចំណាយលម្អិត'
        : 'របាយការណ៍ចំណាយសង្ខេប';

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(24),
        header: (context) => _buildHeader(
          context: context,
          reportTitle: reportTitleKhmer,
          periodSubtitle: period.khmerPeriodTitle,
          primaryColor: primaryColor,
          darkInk: darkInk,
          mutedText: mutedText,
          borderColor: borderColor,
        ),
        footer: (context) => _buildFooter(
          context: context,
          mutedText: mutedText,
          borderColor: borderColor,
        ),
        build: (context) => [
          pw.SizedBox(height: 12),

          // ── KPI Summary Cards ───────────────────────────────────────────
          pw.Row(
            children: [
              _buildKpiCard(
                title: 'ចំណាយសរុប',
                value: riel(totalAmount),
                bgColor: secondaryColor,
                textColor: primaryColor,
                borderColor: borderColor,
              ),
              pw.SizedBox(width: 8),
              _buildKpiCard(
                title: 'ចំនួនប្រតិបត្តិការ',
                value: '$totalCount ដង',
                bgColor: PdfColors.white,
                textColor: darkInk,
                borderColor: borderColor,
              ),
              pw.SizedBox(width: 8),
              _buildKpiCard(
                title: 'ចំនួនមុខចំណាយ',
                value: '${sortedCategories.length} មុខ',
                bgColor: PdfColors.white,
                textColor: darkInk,
                borderColor: borderColor,
              ),
              pw.SizedBox(width: 8),
              _buildKpiCard(
                title: 'មធ្យមភាគ/ដង',
                value: totalCount > 0 ? riel(totalAmount ~/ totalCount) : '0 ៛',
                bgColor: PdfColors.white,
                textColor: darkInk,
                borderColor: borderColor,
              ),
            ],
          ),
          pw.SizedBox(height: 18),

          // ── Category Breakdown Table ─────────────────────────────────────
          pw.Text(
            'សង្ខេបតាមមុខចំណាយ',
            style: pw.TextStyle(
              fontSize: 13,
              fontWeight: pw.FontWeight.bold,
              color: primaryColor,
              lineSpacing: 2,
            ),
          ),
          pw.SizedBox(height: 8),
          _buildCategoryTable(
            sortedCategories: sortedCategories,
            totalAmount: totalAmount,
            totalCount: totalCount,
            primaryColor: primaryColor,
            secondaryColor: secondaryColor,
            borderColor: borderColor,
            darkInk: darkInk,
          ),

          // ── Detailed Transactions Table ─────────────────────────────────
          if (isDetailed) ...[
            pw.SizedBox(height: 20),
            pw.Text(
              'បញ្ជីចំណាយលម្អិត ($totalCount ប្រតិបត្តិការ)',
              style: pw.TextStyle(
                fontSize: 13,
                fontWeight: pw.FontWeight.bold,
                color: primaryColor,
                lineSpacing: 2,
              ),
            ),
            pw.SizedBox(height: 8),
            _buildDetailedTable(
              expenses: filtered,
              primaryColor: primaryColor,
              secondaryColor: secondaryColor,
              borderColor: borderColor,
              darkInk: darkInk,
              mutedText: mutedText,
            ),
          ],
        ],
      ),
    );

    return pdf.save();
  }

  static pw.Widget _buildHeader({
    required pw.Context context,
    required String reportTitle,
    required String periodSubtitle,
    required PdfColor primaryColor,
    required PdfColor darkInk,
    required PdfColor mutedText,
    required PdfColor borderColor,
  }) {
    final now = DateTime.now();
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Row(
                  crossAxisAlignment: pw.CrossAxisAlignment.center,
                  children: [
                    pw.Container(
                      padding: const pw.EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: pw.BoxDecoration(
                        color: primaryColor,
                        borderRadius: const pw.BorderRadius.all(
                          pw.Radius.circular(6),
                        ),
                      ),
                      child: pw.Text(
                        'កត់លុយ',
                        style: pw.TextStyle(
                          color: PdfColors.white,
                          fontSize: 12,
                          fontWeight: pw.FontWeight.bold,
                          lineSpacing: 2,
                        ),
                      ),
                    ),
                    pw.SizedBox(width: 8),
                    pw.Text(
                      'Kot Luy',
                      style: pw.TextStyle(
                        color: mutedText,
                        fontSize: 11,
                        fontWeight: pw.FontWeight.bold,
                        lineSpacing: 1,
                      ),
                    ),
                  ],
                ),
                pw.SizedBox(height: 6),
                pw.Text(
                  'របាយការណ៍កត់ត្រាហិរញ្ញវត្ថុប្រចាំថ្ងៃ',
                  style: pw.TextStyle(
                    fontSize: 9,
                    color: mutedText,
                    lineSpacing: 2,
                  ),
                ),
              ],
            ),
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                pw.Text(
                  reportTitle,
                  style: pw.TextStyle(
                    fontSize: 15,
                    fontWeight: pw.FontWeight.bold,
                    color: primaryColor,
                    lineSpacing: 2,
                  ),
                ),
                pw.SizedBox(height: 3),
                pw.Text(
                  periodSubtitle,
                  style: pw.TextStyle(
                    fontSize: 11,
                    fontWeight: pw.FontWeight.bold,
                    color: darkInk,
                    lineSpacing: 2,
                  ),
                ),
                pw.SizedBox(height: 3),
                pw.Text(
                  'កាលបរិច្ឆេទបង្កើត: ${displayDate(now)}',
                  style: pw.TextStyle(
                    fontSize: 8.5,
                    color: mutedText,
                    lineSpacing: 2,
                  ),
                ),
              ],
            ),
          ],
        ),
        pw.SizedBox(height: 8),
        pw.Divider(color: borderColor, thickness: 1),
      ],
    );
  }

  static pw.Widget _buildFooter({
    required pw.Context context,
    required PdfColor mutedText,
    required PdfColor borderColor,
  }) {
    return pw.Column(
      children: [
        pw.Divider(color: borderColor, thickness: 0.5),
        pw.SizedBox(height: 4),
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(
              'កត់បន្តិចម្ដងៗ ស្គាល់ចំណាយកាន់តែច្បាស់ | កត់លុយ (Kot Luy)',
              style: pw.TextStyle(fontSize: 8.5, color: mutedText, lineSpacing: 2),
            ),
            pw.Text(
              'ទំព័រ ${context.pageNumber} នៃ ${context.pagesCount}',
              style: pw.TextStyle(fontSize: 8.5, color: mutedText, lineSpacing: 2),
            ),
          ],
        ),
      ],
    );
  }

  static pw.Widget _buildKpiCard({
    required String title,
    required String value,
    required PdfColor bgColor,
    required PdfColor textColor,
    required PdfColor borderColor,
  }) {
    return pw.Expanded(
      child: pw.Container(
        padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        decoration: pw.BoxDecoration(
          color: bgColor,
          borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
          border: pw.Border.all(color: borderColor, width: 0.8),
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              title,
              style: pw.TextStyle(
                fontSize: 8.5,
                color: PdfColor.fromHex('#5E6B56'),
                lineSpacing: 2,
              ),
            ),
            pw.SizedBox(height: 4),
            pw.Text(
              value,
              style: pw.TextStyle(
                fontSize: 12,
                fontWeight: pw.FontWeight.bold,
                color: textColor,
                lineSpacing: 2,
              ),
            ),
          ],
        ),
      ),
    );
  }

  static pw.Widget _buildCategoryTable({
    required List<({String label, int count, int total})> sortedCategories,
    required int totalAmount,
    required int totalCount,
    required PdfColor primaryColor,
    required PdfColor secondaryColor,
    required PdfColor borderColor,
    required PdfColor darkInk,
  }) {
    if (sortedCategories.isEmpty) {
      return pw.Container(
        padding: const pw.EdgeInsets.all(16),
        alignment: pw.Alignment.center,
        child: pw.Text(
          'មិនមានទិន្នន័យចំណាយក្នុងកាលកំណត់នេះទេ',
          style: pw.TextStyle(fontSize: 10, color: darkInk),
        ),
      );
    }

    final headers = ['ល.រ', 'មុខចំណាយ', 'ចំនួនដង', 'ចំនួនទឹកប្រាក់', 'ភាគរយ'];
    final data = <List<String>>[];

    for (var i = 0; i < sortedCategories.length; i++) {
      final item = sortedCategories[i];
      final pct = totalAmount > 0
          ? ((item.total / totalAmount) * 100).toStringAsFixed(1)
          : '0.0';
      data.add([
        '${i + 1}',
        item.label,
        '${item.count}',
        riel(item.total),
        '$pct%',
      ]);
    }

    // Add total summary row
    data.add(['', 'សរុប', '$totalCount', riel(totalAmount), '100%']);

    return pw.TableHelper.fromTextArray(
      headers: headers,
      data: data,
      headerStyle: pw.TextStyle(
        fontWeight: pw.FontWeight.bold,
        color: PdfColors.white,
        fontSize: 9,
        lineSpacing: 2,
      ),
      headerDecoration: pw.BoxDecoration(color: primaryColor),
      headerHeight: 30,
      headerPadding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      cellHeight: 28,
      cellPadding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      cellStyle: pw.TextStyle(
        fontSize: 8.5,
        color: darkInk,
        lineSpacing: 2,
      ),
      cellAlignment: pw.Alignment.centerLeft,
      cellAlignments: {
        0: pw.Alignment.center,
        1: pw.Alignment.centerLeft,
        2: pw.Alignment.center,
        3: pw.Alignment.centerRight,
        4: pw.Alignment.centerRight,
      },
      oddRowDecoration: pw.BoxDecoration(color: secondaryColor),
      border: pw.TableBorder.all(color: borderColor, width: 0.5),
    );
  }

  static pw.Widget _buildDetailedTable({
    required List<Expense> expenses,
    required PdfColor primaryColor,
    required PdfColor secondaryColor,
    required PdfColor borderColor,
    required PdfColor darkInk,
    required PdfColor mutedText,
  }) {
    if (expenses.isEmpty) {
      return pw.Container();
    }

    final headers = ['ល.រ', 'កាលបរិច្ឆេទ', 'មុខចំណាយ', 'ចំនួនទឹកប្រាក់', 'កំណត់ចំណាំ'];
    final data = <List<String>>[];

    for (var i = 0; i < expenses.length; i++) {
      final e = expenses[i];
      final dateStr =
          '${displayDate(e.date)} ${formatTime(e.date)}';
      data.add([
        '${i + 1}',
        dateStr,
        e.category.label,
        riel(e.amount),
        e.note.isEmpty ? '-' : e.note,
      ]);
    }

    return pw.TableHelper.fromTextArray(
      headers: headers,
      data: data,
      headerStyle: pw.TextStyle(
        fontWeight: pw.FontWeight.bold,
        color: PdfColors.white,
        fontSize: 9,
        lineSpacing: 2,
      ),
      headerDecoration: pw.BoxDecoration(color: primaryColor),
      headerHeight: 30,
      headerPadding: const pw.EdgeInsets.symmetric(horizontal: 7, vertical: 6),
      cellHeight: 28,
      cellPadding: const pw.EdgeInsets.symmetric(horizontal: 7, vertical: 6),
      cellStyle: pw.TextStyle(
        fontSize: 8.5,
        color: darkInk,
        lineSpacing: 2,
      ),
      cellAlignment: pw.Alignment.centerLeft,
      cellAlignments: {
        0: pw.Alignment.center,
        1: pw.Alignment.centerLeft,
        2: pw.Alignment.centerLeft,
        3: pw.Alignment.centerRight,
        4: pw.Alignment.centerLeft,
      },
      oddRowDecoration: pw.BoxDecoration(color: secondaryColor),
      border: pw.TableBorder.all(color: borderColor, width: 0.5),
    );
  }
}
