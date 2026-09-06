import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kot_loy/widgets/riel_input_formatter.dart';

void main() {
  final formatter = RielInputFormatter();
  TextEditingValue value(String text, [int? cursor]) => TextEditingValue(
    text: text,
    selection: TextSelection.collapsed(offset: cursor ?? text.length),
  );
  test('groups typing and pasted amounts, retains twelve-digit limit', () {
    expect(
      formatter.formatEditUpdate(value(''), value('20000')).text,
      '20,000',
    );
    expect(
      formatter.formatEditUpdate(value(''), value('1,234,567')).text,
      '1,234,567',
    );
    expect(
      formatter.formatEditUpdate(value(''), value('999999999999')).text,
      '999,999,999,999',
    );
    final previous = value('999,999,999,999');
    expect(
      formatter.formatEditUpdate(previous, value('9999999999999')),
      previous,
    );
    expect(formatter.formatEditUpdate(value('20,000'), value('')).text, '');
  });
  test('mid-number edits and deleting separators keep a useful cursor', () {
    final inserted = formatter.formatEditUpdate(
      value('20,000', 1),
      value('250,000', 2),
    );
    expect(inserted.text, '250,000');
    expect(inserted.selection.extentOffset, 2);
    final backspace = formatter.formatEditUpdate(
      value('20,000', 3),
      value('20000', 2),
    );
    expect(backspace.text, '2,000');
    expect(backspace.selection.extentOffset, 1);
    final delete = formatter.formatEditUpdate(
      value('20,000', 2),
      value('20000', 2),
    );
    expect(delete.text, '2,000');
    expect(delete.selection.extentOffset, 3);
  });
}
