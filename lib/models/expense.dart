import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

enum ExpenseCategory {
  food('អាហារ', Icons.restaurant_rounded, Color(0xFF658B62), Color(0xFFEAF0E1)),
  coffee(
    'កាហ្វេ',
    Icons.local_cafe_outlined,
    Color(0xFFAF805D),
    Color(0xFFF3E8DD),
  ),
  transport(
    'ធ្វើដំណើរ',
    Icons.directions_bus_outlined,
    Color(0xFF688C9B),
    Color(0xFFE5EEF1),
  ),
  shopping(
    'ទិញទំនិញ',
    Icons.shopping_bag_outlined,
    Color(0xFFBA8C94),
    Color(0xFFF6E8EB),
  ),
  bills(
    'វិក្កយបត្រ',
    Icons.receipt_long_outlined,
    Color(0xFFA19563),
    Color(0xFFF4F0DE),
  ),
  other(
    'ផ្សេងៗ',
    Icons.more_horiz_rounded,
    Color(0xFF8B80A7),
    Color(0xFFEDE9F4),
  );

  const ExpenseCategory(this.label, this.icon, this.color, this.background);
  final String label;
  final IconData icon;
  final Color color;
  final Color background;
}

class Expense {
  const Expense({
    this.id,
    required this.title,
    required this.amount,
    required this.category,
    required this.date,
    this.note = '',
  });
  final int? id;
  final String title;
  final int amount;
  final ExpenseCategory category;
  final DateTime date;
  final String note;
  Map<String, Object?> toMap() => {
    if (id != null) 'id': id,
    'title': title,
    'amount': amount,
    'category': category.name,
    'date': date.millisecondsSinceEpoch,
    'note': note,
  };
  factory Expense.fromMap(Map<String, Object?> map) => Expense(
    id: map['id'] as int,
    title: map['title'] as String,
    amount: map['amount'] as int,
    category: ExpenseCategory.values.byName(map['category'] as String),
    date: DateTime.fromMillisecondsSinceEpoch(map['date'] as int),
    note: map['note'] as String,
  );
}

enum ExpensePeriod {
  today('ថ្ងៃនេះ'),
  week('សប្ដាហ៍នេះ'),
  month('ខែនេះ'),
  all('ទាំងអស់');

  const ExpensePeriod(this.label);
  final String label;
  bool contains(DateTime date, DateTime now) {
    final startOfDay = DateTime(now.year, now.month, now.day);
    return switch (this) {
      today =>
        !date.isBefore(startOfDay) &&
            date.isBefore(startOfDay.add(const Duration(days: 1))),
      week =>
        !date.isBefore(
              startOfDay.subtract(Duration(days: startOfDay.weekday - 1)),
            ) &&
            date.isBefore(
              startOfDay.add(Duration(days: 8 - startOfDay.weekday)),
            ),
      month => date.year == now.year && date.month == now.month,
      all => true,
    };
  }
}

String riel(int value) => '${NumberFormat('#,##0', 'en').format(value)} ៛';
const khmerMonths = [
  'មករា',
  'កុម្ភៈ',
  'មីនា',
  'មេសា',
  'ឧសភា',
  'មិថុនា',
  'កក្កដា',
  'សីហា',
  'កញ្ញា',
  'តុលា',
  'វិច្ឆិកា',
  'ធ្នូ',
];
String displayDate(DateTime date) =>
    '${date.day} ${khmerMonths[date.month - 1]} ${date.year}';
String dayLabel(DateTime date, DateTime now) {
  final day = DateTime(date.year, date.month, date.day);
  final today = DateTime(now.year, now.month, now.day);
  if (day == today) return 'ថ្ងៃនេះ';
  if (day == today.subtract(const Duration(days: 1))) return 'ម្សិលមិញ';
  return displayDate(date);
}
