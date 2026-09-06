import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:pdf_text_shaper/pdf_text_shaper.dart';

void main() {
  test('HarfBuzz shapes Khmer strings with NotoSansKhmer fonts', () async {
    final regularBytes = await File('assets/fonts/NotoSansKhmer-Regular.ttf').readAsBytes();
    final boldBytes = await File('assets/fonts/NotoSansKhmer-Bold.ttf').readAsBytes();

    final regularFont = ShapedFont.fromBytes(regularBytes, name: 'NotoSansKhmer-Regular');
    final boldFont = ShapedFont.fromBytes(boldBytes, name: 'NotoSansKhmer-Bold');

    try {
      final doc = pw.Document();
      doc.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          build: (context) {
            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                ShapedText(
                  'របាយការណ៍ចំណាយប្រចាំខែ',
                  style: ShapedTextStyle(font: boldFont, fontSize: 16),
                ),
                ShapedText(
                  'ចំណាយសរុប: 1,065,000 ៛ (\$260.00)',
                  style: ShapedTextStyle(font: regularFont, fontSize: 12),
                ),
                ShapedText(
                  'ប្រភពចំណូល និង បញ្ជីចំណាយលម្អិត',
                  style: ShapedTextStyle(font: regularFont, fontSize: 12),
                ),
              ],
            );
          },
        ),
      );

      final pdfBytes = await doc.save();
      expect(pdfBytes.length, greaterThan(1000));
      await File('build/test_khmer_sample.pdf').writeAsBytes(pdfBytes);
    } finally {
      regularFont.dispose();
      boldFont.dispose();
    }
  });
}
