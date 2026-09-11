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

const _tens = [
  '',
  'ដប់',
  'ម្ភៃ',
  'សាមសិប',
  'សែសិប',
  'ហាសិប',
  'ហុកសិប',
  'ចិតសិប',
  'ប៉ែតសិប',
  'កៅសិប',
];

const _placesBelowMillion = [
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

  return _readPositive(value);
}

String _readPositive(int value) {
  final result = StringBuffer();
  var remainder = value;

  // Khmer numbers above one million keep the lower six place values as one
  // group. The leading group is read naturally, then followed by `លាន`.
  // Recursing here also supports billions, trillions, and larger Dart ints.
  if (remainder >= 1000000) {
    final millions = remainder ~/ 1000000;
    result
      ..write(_readPositive(millions))
      ..write('លាន');
    remainder %= 1000000;
  }

  for (final place in _placesBelowMillion) {
    final count = remainder ~/ place.$1;
    if (count == 0) continue;
    result.write(_digits[count]);
    result.write(place.$2);
    remainder %= place.$1;
  }
  if (remainder >= 20) {
    final tens = remainder ~/ 10;
    result.write(_tens[tens]);
    remainder %= 10;
  } else if (remainder >= 10) {
    result.write('ដប់');
    remainder -= 10;
  }
  if (remainder > 0) result.write(_digits[remainder]);
  return result.toString();
}

String khmerRielWords(int value) => '${khmerNumberWords(value)}រៀល';
