import 'package:flutter/services.dart';

String normalizeKhmerDigits(String input) => input.replaceAllMapped(
  RegExp(r'[\u17E0-\u17E9]'),
  (m) => (m[0]!.codeUnitAt(0) - 0x17E0).toString(),
);

String formatRielInput(String digits) {
  final clean = normalizeKhmerDigits(digits).replaceAll(RegExp(r'[^0-9]'), '');
  return clean.replaceAllMapped(
    RegExp(r'(\d)(?=(\d{3})+$)'),
    (match) => '${match[1]},',
  );
}

int parseRielInput(String? text) {
  if (text == null || text.isEmpty) return 0;
  final clean = normalizeKhmerDigits(text).replaceAll(RegExp(r'[^0-9]'), '');
  return int.tryParse(clean) ?? 0;
}

class RielInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (!newValue.composing.isCollapsed) return newValue;
    var text = normalizeKhmerDigits(newValue.text);
    var cursor = newValue.selection.extentOffset.clamp(0, text.length);

    // Backspacing a separator removes the preceding digit, so the cursor
    // never gets stuck repeatedly recreating the same comma.
    if (oldValue.selection.isCollapsed &&
        newValue.selection.isCollapsed &&
        oldValue.text.length == text.length + 1) {
      final oldCursor = oldValue.selection.extentOffset;
      if (oldCursor == cursor + 1 &&
          cursor > 0 &&
          oldValue.text[cursor] == ',') {
        text = text.replaceRange(cursor - 1, cursor, '');
        cursor--;
      } else if (oldCursor == cursor &&
          cursor < oldValue.text.length &&
          oldValue.text[cursor] == ',' &&
          cursor < text.length) {
        text = text.replaceRange(cursor, cursor + 1, '');
      }
    }
    final digits = text.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.length > 12) return oldValue;
    final digitsBeforeCursor = text
        .substring(0, cursor)
        .replaceAll(RegExp(r'[^0-9]'), '')
        .length;
    final formatted = formatRielInput(digits);
    var offset = 0;
    var seen = 0;
    while (offset < formatted.length && seen < digitsBeforeCursor) {
      if (formatted[offset] != ',') seen++;
      offset++;
    }
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: offset),
    );
  }
}
