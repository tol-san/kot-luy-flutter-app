import 'package:flutter/services.dart';

String formatRielInput(String digits) => digits.replaceAllMapped(
  RegExp(r'(\d)(?=(\d{3})+$)'),
  (match) => '${match[1]},',
);

class RielInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (!newValue.composing.isCollapsed) return newValue;
    var text = newValue.text;
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
