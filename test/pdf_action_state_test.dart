import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';
import 'package:printing/src/interface.dart';
import 'package:kot_luy/pdf/pdf_downloader.dart';
import 'package:kot_luy/screens/pdf_export_sheet.dart';

import 'pdf_export_sheet_test.dart' show FakeExpenseRepository;

class PendingPrinter extends PrintingPlatform {
  final result = Completer<bool>();
  int calls = 0;

  @override
  Future<bool> layoutPdf(
    Printer? printer,
    LayoutCallback onLayout,
    String name,
    PdfPageFormat format,
    bool dynamicLayout,
    bool usePrinterSettings,
    OutputType outputType,
    bool forceCustomPrintPaper,
    bool windowsModernDialog,
  ) {
    calls++;
    return result.future;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnsupportedError('Unexpected printing operation');
}

void main() {
  for (final outcome in ['printed', 'cancelled', 'failed', 'download failed']) {
    testWidgets('Only the active PDF button loads; restores after $outcome', (
      tester,
    ) async {
      final printer = PendingPrinter();
      final originalPrinter = PrintingPlatform.instance;
      PrintingPlatform.instance = printer;
      final download = Completer<PdfDownloadResult?>();
      var downloadCalls = 0;
      PdfDownloader.saveOverride = (_, _) {
        downloadCalls++;
        return download.future;
      };
      addTearDown(() {
        PrintingPlatform.instance = originalPrinter;
        PdfDownloader.saveOverride = null;
      });
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PdfExportSheet(repository: FakeExpenseRepository([])),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final preview = find.byKey(const Key('previewPdfButton'));
      final save = find.byKey(const Key('downloadPdfButton'));
      final downloading = outcome == 'download failed';
      final active = downloading ? save : preview;
      final inactive = downloading ? preview : save;
      await tester.tap(active);
      for (var i = 0; i < 100 && printer.calls + downloadCalls == 0; i++) {
        await tester.pump(const Duration(milliseconds: 20));
      }
      expect(printer.calls + downloadCalls, 1);
      await tester.pump();
      expect(
        find.descendant(
          of: active,
          matching: find.byType(CircularProgressIndicator),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: inactive,
          matching: find.byType(CircularProgressIndicator),
        ),
        findsNothing,
      );
      expect(
        find.text(downloading ? 'មើល / បោះពុម្ព' : 'ទាញយក PDF'),
        findsOneWidget,
      );
      expect(tester.widget<ButtonStyleButton>(preview).onPressed, isNull);
      expect(tester.widget<ButtonStyleButton>(save).onPressed, isNull);
      await tester.tap(inactive);
      await tester.pump(const Duration(milliseconds: 20));
      expect(printer.calls + downloadCalls, 1);
      if (downloading) {
        download.completeError(Exception('Download failed'));
      } else if (outcome == 'failed') {
        printer.result.completeError(Exception('Print failed'));
      } else {
        printer.result.complete(outcome == 'printed');
      }
      await tester.pumpAndSettle();
      expect(tester.widget<ButtonStyleButton>(preview).onPressed, isNotNull);
      expect(tester.widget<ButtonStyleButton>(save).onPressed, isNotNull);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.text('មើល / បោះពុម្ព'), findsOneWidget);
      expect(find.text('ទាញយក PDF'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
