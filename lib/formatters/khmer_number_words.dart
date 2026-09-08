const _digits = [
  'សូន្យ',
  'មួយ',
  'ពីរ',
  'បី',
  'បួន',
  'ប្រាំ',
  'ប្រាំមួយ',
  'ប្រាំពីរ',
  'ប្រាំបី',
  'ប្រាំបួន',
];

const _places = [
  (100000000000, 'សែនលាន'),
  (10000000000, 'ម៉ឺនលាន'),
  (1000000000, 'ពាន់លាន'),
  (100000000, 'រយលាន'),
  (10000000, 'ដប់លាន'),
  (1000000, 'លាន'),
  (100000, 'សែន'),
  (10000, 'ម៉ឺន'),
  (1000, 'ពាន់'),
  (100, 'រយ'),
];

/// Converts a non-negative whole number into standard Khmer number words.
///
/// For example, 27000 becomes `ពីរម៉ឺនប្រាំពីរពាន់`.
String khmerNumberWords(int value) {
  if (value < 0) {
    throw ArgumentError.value(value, 'value', 'Must not be negative');
  }
  if (value == 0) return _digits.first;

  var remainder = value;
  final result = StringBuffer();
  for (final place in _places) {
    final count = remainder ~/ place.$1;
    if (count == 0) continue;
    result.write(_digits[count]);
    result.write(place.$2);
    remainder %= place.$1;
  }
  if (remainder >= 20) {
    final tens = remainder ~/ 10;
    result.write(tens == 2 ? 'ម្ភៃ' : '${_digits[tens]}ដប់');
    remainder %= 10;
  } else if (remainder >= 10) {
    result.write('ដប់');
    remainder -= 10;
  }
  if (remainder > 0) result.write(_digits[remainder]);
  return result.toString();
}

String khmerRielWords(int value) => '${khmerNumberWords(value)}រៀល';
