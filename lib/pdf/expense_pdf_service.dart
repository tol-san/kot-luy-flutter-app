import 'dart:io';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:pdf_text_shaper/pdf_text_shaper.dart';

import '../models/expense.dart';
import '../models/report_period.dart';

class ExpensePdfService {
  static Future<Uint8List> _loadFontBytes(String path) async {
    try {
      final byteData = await rootBundle.load(path);
      return byteData.buffer.asUint8List(
        byteData.offsetInBytes,
        byteData.lengthInBytes,
      );
    } catch (_) {
      // Fallback for tests running outside Flutter asset bundle context
      return await File(path).readAsBytes();
    }
  }

  /// Builds PDF byte data for the given [expenses], [period], and [level].
  /// Uses HarfBuzz OpenType complex-script shaping with Noto Sans Khmer fonts.
  static Future<Uint8List> generateReport({
    required List<Expense> expenses,
    required ReportPeriodConfig period,
    required ReportDetailLevel level,
    pw.Font? regularFont,
    pw.Font? boldFont,
    ShapedFont? shapedRegularFont,
    ShapedFont? shapedBoldFont,
    Uint8List? regularFontBytes,
    Uint8List? boldFontBytes,
  }) async {
    // 1. Load font bytes and prepare shaped fonts
    final regBytes = regularFontBytes ??
        (shapedRegularFont == null
            ? await _loadFontBytes('assets/fonts/NotoSansKhmer-Regular.ttf')
            : null);
    final bldBytes = boldFontBytes ??
        (shapedBoldFont == null
            ? await _loadFontBytes('assets/fonts/NotoSansKhmer-Bold.ttf')
            : null);

    final bool ownsRegular = shapedRegularFont == null;
    final bool ownsBold = shapedBoldFont == null;

    final effectiveRegular = shapedRegularFont ??
        ShapedFont.fromBytes(regBytes!, name: 'NotoSansKhmer-Regular');
    final effectiveBold = shapedBoldFont ??
        ShapedFont.fromBytes(bldBytes!, name: 'NotoSansKhmer-Bold');

    try {
      final baseFont = regularFont ??
          (regBytes != null
              ? pw.Font.ttf(
                  ByteData.sublistView(regBytes),
                )
              : null);
      final headerFont = boldFont ??
          (bldBytes != null
              ? pw.Font.ttf(
                  ByteData.sublistView(bldBytes),
                )
              : null);

      final theme = (baseFont != null && headerFont != null)
          ? pw.ThemeData.withFont(
              base: baseFont,
              bold: headerFont,
            )
          : pw.ThemeData.base();

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
            regularFont: effectiveRegular,
            boldFont: effectiveBold,
          ),
          footer: (context) => _buildFooter(
            context: context,
            mutedText: mutedText,
            borderColor: borderColor,
            regularFont: effectiveRegular,
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
                  regularFont: effectiveRegular,
                  boldFont: effectiveBold,
                ),
                pw.SizedBox(width: 8),
                _buildKpiCard(
                  title: 'ចំនួនប្រតិបត្តិការ',
                  value: '$totalCount ដង',
                  bgColor: PdfColors.white,
                  textColor: darkInk,
                  borderColor: borderColor,
                  regularFont: effectiveRegular,
                  boldFont: effectiveBold,
                ),
                pw.SizedBox(width: 8),
                _buildKpiCard(
                  title: 'ចំនួនមុខចំណាយ',
                  value: '${sortedCategories.length} មុខ',
                  bgColor: PdfColors.white,
                  textColor: darkInk,
                  borderColor: borderColor,
                  regularFont: effectiveRegular,
                  boldFont: effectiveBold,
                ),
                pw.SizedBox(width: 8),
                _buildKpiCard(
                  title: 'មធ្យមភាគ/ដង',
                  value: totalCount > 0 ? riel(totalAmount ~/ totalCount) : '0 ៛',
                  bgColor: PdfColors.white,
                  textColor: darkInk,
                  borderColor: borderColor,
                  regularFont: effectiveRegular,
                  boldFont: effectiveBold,
                ),
              ],
            ),
            pw.SizedBox(height: 18),

            // ── Category Breakdown Table ─────────────────────────────────────
            ShapedText(
              'សង្ខេបតាមមុខចំណាយ',
              language: 'km',
              style: ShapedTextStyle(
                fontSize: 13,
                color: primaryColor,
                font: effectiveBold,
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
              regularFont: effectiveRegular,
              boldFont: effectiveBold,
            ),

            // ── Detailed Transactions Table ─────────────────────────────────
            if (isDetailed) ...[
              pw.SizedBox(height: 20),
              ShapedText(
                'បញ្ជីចំណាយលម្អិត ($totalCount ប្រតិបត្តិការ)',
                language: 'km',
                style: ShapedTextStyle(
                  fontSize: 13,
                  color: primaryColor,
                  font: effectiveBold,
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
                regularFont: effectiveRegular,
                boldFont: effectiveBold,
              ),
            ],
          ],
        ),
      );

      return await pdf.save();
    } finally {
      if (ownsRegular) effectiveRegular.dispose();
      if (ownsBold) effectiveBold.dispose();
    }
  }

  static pw.Widget _buildHeader({
    required pw.Context context,
    required String reportTitle,
    required String periodSubtitle,
    required PdfColor primaryColor,
    required PdfColor darkInk,
    required PdfColor mutedText,
    required PdfColor borderColor,
    required ShapedFont regularFont,
    required ShapedFont boldFont,
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
                      child: ShapedText(
                        'កត់លុយ',
                        language: 'km',
                        style: ShapedTextStyle(
                          color: PdfColors.white,
                          fontSize: 12,
                          font: boldFont,
                        ),
                      ),
                    ),
                    pw.SizedBox(width: 8),
                    ShapedText(
                      'Kot Luy',
                      style: ShapedTextStyle(
                        color: mutedText,
                        fontSize: 11,
                        font: boldFont,
                      ),
                    ),
                  ],
                ),
                pw.SizedBox(height: 6),
                ShapedText(
                  'របាយការណ៍កត់ត្រាហិរញ្ញវត្ថុប្រចាំថ្ងៃ',
                  language: 'km',
                  style: ShapedTextStyle(
                    fontSize: 9,
                    color: mutedText,
                    font: regularFont,
                  ),
                ),
              ],
            ),
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                ShapedText(
                  reportTitle,
                  language: 'km',
                  style: ShapedTextStyle(
                    fontSize: 15,
                    color: primaryColor,
                    font: boldFont,
                    align: ShapedTextAlign.end,
                  ),
                ),
                pw.SizedBox(height: 3),
                ShapedText(
                  periodSubtitle,
                  language: 'km',
                  style: ShapedTextStyle(
                    fontSize: 11,
                    color: darkInk,
                    font: boldFont,
                    align: ShapedTextAlign.end,
                  ),
                ),
                pw.SizedBox(height: 3),
                ShapedText(
                  'កាលបរិច្ឆេទបង្កើត: ${displayDate(now)}',
                  language: 'km',
                  style: ShapedTextStyle(
                    fontSize: 8.5,
                    color: mutedText,
                    font: regularFont,
                    align: ShapedTextAlign.end,
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
    required ShapedFont regularFont,
  }) {
    return pw.Column(
      children: [
        pw.Divider(color: borderColor, thickness: 0.5),
        pw.SizedBox(height: 4),
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            ShapedText(
              'កត់បន្តិចម្ដងៗ ស្គាល់ចំណាយកាន់តែច្បាស់ | កត់លុយ (Kot Luy)',
              language: 'km',
              style: ShapedTextStyle(
                fontSize: 8.5,
                color: mutedText,
                font: regularFont,
              ),
            ),
            ShapedText(
              'ទំព័រ ${context.pageNumber} នៃ ${context.pagesCount}',
              language: 'km',
              style: ShapedTextStyle(
                fontSize: 8.5,
                color: mutedText,
                font: regularFont,
                align: ShapedTextAlign.end,
              ),
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
    required ShapedFont regularFont,
    required ShapedFont boldFont,
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
            ShapedText(
              title,
              language: 'km',
              style: ShapedTextStyle(
                fontSize: 8.5,
                color: PdfColor.fromHex('#5E6B56'),
                font: regularFont,
              ),
            ),
            pw.SizedBox(height: 4),
            ShapedText(
              value,
              language: 'km',
              style: ShapedTextStyle(
                fontSize: 12,
                color: textColor,
                font: boldFont,
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
    required ShapedFont regularFont,
    required ShapedFont boldFont,
  }) {
    if (sortedCategories.isEmpty) {
      return pw.Container(
        padding: const pw.EdgeInsets.all(16),
        alignment: pw.Alignment.center,
        child: ShapedText(
          'មិនមានទិន្នន័យចំណាយក្នុងកាលកំណត់នេះទេ',
          language: 'km',
          style: ShapedTextStyle(
            fontSize: 10,
            color: darkInk,
            font: regularFont,
            align: ShapedTextAlign.center,
          ),
        ),
      );
    }

    pw.Widget cell(
      String text, {
      required ShapedFont font,
      required double fontSize,
      required PdfColor color,
      ShapedTextAlign align = ShapedTextAlign.start,
    }) {
      return pw.Padding(
        padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: ShapedText(
          text,
          language: 'km',
          style: ShapedTextStyle(
            font: font,
            fontSize: fontSize,
            color: color,
            align: align,
          ),
        ),
      );
    }

    return pw.Table(
      border: pw.TableBorder.all(color: borderColor, width: 0.5),
      columnWidths: {
        0: const pw.FixedColumnWidth(34),
        1: const pw.FlexColumnWidth(3),
        2: const pw.FlexColumnWidth(1.4),
        3: const pw.FlexColumnWidth(2),
        4: const pw.FlexColumnWidth(1.4),
      },
      children: [
        pw.TableRow(
          repeat: true,
          decoration: pw.BoxDecoration(color: primaryColor),
          children: [
            cell('ល.រ', font: boldFont, fontSize: 9, color: PdfColors.white, align: ShapedTextAlign.center),
            cell('មុខចំណាយ', font: boldFont, fontSize: 9, color: PdfColors.white, align: ShapedTextAlign.start),
            cell('ចំនួនដង', font: boldFont, fontSize: 9, color: PdfColors.white, align: ShapedTextAlign.center),
            cell('ចំនួនទឹកប្រាក់', font: boldFont, fontSize: 9, color: PdfColors.white, align: ShapedTextAlign.end),
            cell('ភាគរយ', font: boldFont, fontSize: 9, color: PdfColors.white, align: ShapedTextAlign.end),
          ],
        ),
        ...sortedCategories.asMap().entries.map((entry) {
          final i = entry.key;
          final item = entry.value;
          final isOdd = i % 2 == 1;
          final pct = totalAmount > 0
              ? ((item.total / totalAmount) * 100).toStringAsFixed(1)
              : '0.0';
          return pw.TableRow(
            decoration: isOdd ? pw.BoxDecoration(color: secondaryColor) : null,
            children: [
              cell('${i + 1}', font: regularFont, fontSize: 8.5, color: darkInk, align: ShapedTextAlign.center),
              cell(item.label, font: regularFont, fontSize: 8.5, color: darkInk, align: ShapedTextAlign.start),
              cell('${item.count}', font: regularFont, fontSize: 8.5, color: darkInk, align: ShapedTextAlign.center),
              cell(riel(item.total), font: regularFont, fontSize: 8.5, color: darkInk, align: ShapedTextAlign.end),
              cell('$pct%', font: regularFont, fontSize: 8.5, color: darkInk, align: ShapedTextAlign.end),
            ],
          );
        }),
        // Summary row
        pw.TableRow(
          children: [
            cell('', font: boldFont, fontSize: 8.5, color: darkInk, align: ShapedTextAlign.center),
            cell('សរុប', font: boldFont, fontSize: 8.5, color: darkInk, align: ShapedTextAlign.start),
            cell('$totalCount', font: boldFont, fontSize: 8.5, color: darkInk, align: ShapedTextAlign.center),
            cell(riel(totalAmount), font: boldFont, fontSize: 8.5, color: darkInk, align: ShapedTextAlign.end),
            cell('100%', font: boldFont, fontSize: 8.5, color: darkInk, align: ShapedTextAlign.end),
          ],
        ),
      ],
    );
  }

  static pw.Widget _buildDetailedTable({
    required List<Expense> expenses,
    required PdfColor primaryColor,
    required PdfColor secondaryColor,
    required PdfColor borderColor,
    required PdfColor darkInk,
    required PdfColor mutedText,
    required ShapedFont regularFont,
    required ShapedFont boldFont,
  }) {
    if (expenses.isEmpty) {
      return pw.Container();
    }

    pw.Widget cell(
      String text, {
      required ShapedFont font,
      required double fontSize,
      required PdfColor color,
      ShapedTextAlign align = ShapedTextAlign.start,
    }) {
      return pw.Padding(
        padding: const pw.EdgeInsets.symmetric(horizontal: 7, vertical: 6),
        child: ShapedText(
          text,
          language: 'km',
          style: ShapedTextStyle(
            font: font,
            fontSize: fontSize,
            color: color,
            align: align,
          ),
        ),
      );
    }

    return pw.Table(
      border: pw.TableBorder.all(color: borderColor, width: 0.5),
      columnWidths: {
        0: const pw.FixedColumnWidth(30),
        1: const pw.FlexColumnWidth(2.6),
        2: const pw.FlexColumnWidth(2.4),
        3: const pw.FlexColumnWidth(2),
        4: const pw.FlexColumnWidth(3),
      },
      children: [
        pw.TableRow(
          repeat: true,
          decoration: pw.BoxDecoration(color: primaryColor),
          children: [
            cell('ល.រ', font: boldFont, fontSize: 9, color: PdfColors.white, align: ShapedTextAlign.center),
            cell('កាលបរិច្ឆេទ', font: boldFont, fontSize: 9, color: PdfColors.white, align: ShapedTextAlign.start),
            cell('មុខចំណាយ', font: boldFont, fontSize: 9, color: PdfColors.white, align: ShapedTextAlign.start),
            cell('ចំនួនទឹកប្រាក់', font: boldFont, fontSize: 9, color: PdfColors.white, align: ShapedTextAlign.end),
            cell('កំណត់ចំណាំ', font: boldFont, fontSize: 9, color: PdfColors.white, align: ShapedTextAlign.start),
          ],
        ),
        ...expenses.asMap().entries.map((entry) {
          final i = entry.key;
          final e = entry.value;
          final isOdd = i % 2 == 1;
          final dateStr = '${displayDate(e.date)} ${formatTime(e.date)}';
          return pw.TableRow(
            decoration: isOdd ? pw.BoxDecoration(color: secondaryColor) : null,
            children: [
              cell('${i + 1}', font: regularFont, fontSize: 8.5, color: darkInk, align: ShapedTextAlign.center),
              cell(dateStr, font: regularFont, fontSize: 8.5, color: darkInk, align: ShapedTextAlign.start),
              cell(e.category.label, font: regularFont, fontSize: 8.5, color: darkInk, align: ShapedTextAlign.start),
              cell(riel(e.amount), font: regularFont, fontSize: 8.5, color: darkInk, align: ShapedTextAlign.end),
              cell(e.note.isEmpty ? '-' : e.note, font: regularFont, fontSize: 8.5, color: darkInk, align: ShapedTextAlign.start),
            ],
          );
        }),
      ],
    );
  }
}
