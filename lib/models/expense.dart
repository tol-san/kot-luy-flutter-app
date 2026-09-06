import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class ExpenseCategory {
  const ExpenseCategory({
    required this.name,
    required this.label,
    required this.icon,
    required this.color,
    required this.background,
    this.isCustom = false,
  });

  final String name;
  final String label;
  final IconData icon;
  final Color color;
  final Color background;
  final bool isCustom;

  static const breakfast = ExpenseCategory(
    name: 'breakfast',
    label: 'បាយពេលព្រឹក',
    icon: Icons.wb_sunny_outlined,
    color: Color(0xFFE08D46),
    background: Color(0xFFF9EFE6),
  );
  static const lunch = ExpenseCategory(
    name: 'lunch',
    label: 'បាយថ្ងៃត្រង់',
    icon: Icons.restaurant_rounded,
    color: Color(0xFF658B62),
    background: Color(0xFFEAF0E1),
  );
  static const dinner = ExpenseCategory(
    name: 'dinner',
    label: 'បាយល្ងាច',
    icon: Icons.nights_stay_outlined,
    color: Color(0xFF8B6B55),
    background: Color(0xFFF1EAE4),
  );
  static const fuel = ExpenseCategory(
    name: 'fuel',
    label: 'ចាក់សាំង',
    icon: Icons.local_gas_station_rounded,
    color: Color(0xFF5C8395),
    background: Color(0xFFE4EEF2),
  );
  static const coffee = ExpenseCategory(
    name: 'coffee',
    label: 'កាហ្វេ',
    icon: Icons.local_cafe_outlined,
    color: Color(0xFFAF805D),
    background: Color(0xFFF3E8DD),
  );
  static const other = ExpenseCategory(
    name: 'other',
    label: 'ផ្សេងៗ',
    icon: Icons.more_horiz_rounded,
    color: Color(0xFF8B80A7),
    background: Color(0xFFEDE9F4),
  );

  static const List<ExpenseCategory> values = [
    breakfast,
    lunch,
    dinner,
    fuel,
    coffee,
  ];

  static const List<Color> autoColors = [
    Color(0xFFE08D46), // orange
    Color(0xFF658B62), // sage green
    Color(0xFF8B6B55), // warm brown
    Color(0xFF5C8395), // slate blue
    Color(0xFFAF805D), // caramel
    Color(0xFF8B80A7), // lavender
    Color(0xFFC26D6D), // coral
    Color(0xFF4C8D7B), // teal
    Color(0xFF8A8454), // olive
    Color(0xFF766FA4), // violet
    Color(0xFFB57C48), // amber
    Color(0xFF587D9D), // steel blue
  ];

  static Color autoBackground(Color color) {
    return Color.alphaBlend(color.withValues(alpha: 0.12), Colors.white);
  }

  static ExpenseCategory byName(String name, [List<ExpenseCategory>? known]) =>
      fromName(name, known);

  static ExpenseCategory fromName(String name, [List<ExpenseCategory>? known]) {
    if (known != null) {
      for (final c in known) {
        if (c.name == name) return c;
      }
    }
    return switch (name) {
      'breakfast' => breakfast,
      'lunch' || 'food' => lunch,
      'dinner' => dinner,
      'fuel' || 'transport' => fuel,
      'coffee' => coffee,
      'other' => other,
      _ => ExpenseCategory(
          name: name,
          label: name.startsWith('custom_') ? name.substring(7) : name,
          icon: Icons.local_offer_outlined,
          color: autoColors[name.hashCode.abs() % autoColors.length],
          background: autoBackground(
            autoColors[name.hashCode.abs() % autoColors.length],
          ),
          isCustom: true,
        ),
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ExpenseCategory &&
          runtimeType == other.runtimeType &&
          name == other.name;

  @override
  int get hashCode => name.hashCode;
}

extension ExpenseCategoryListExt on Iterable<ExpenseCategory> {
  ExpenseCategory byName(String name) {
    for (final c in this) {
      if (c.name == name) return c;
    }
    return ExpenseCategory.fromName(name);
  }
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
    'id': id,
    'title': title,
    'amount': amount,
    'category': category.name,
    'date': date.millisecondsSinceEpoch,
    'note': note,
  };
  factory Expense.fromMap(
    Map<String, Object?> map, [
    List<ExpenseCategory>? categories,
  ]) => Expense(
    id: map['id'] as int?,
    title: map['title'] as String,
    amount: map['amount'] as int,
    category: ExpenseCategory.fromName(map['category'] as String, categories),
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

String formatTime(DateTime date) {
  final h = date.hour % 12 == 0 ? 12 : date.hour % 12;
  final minute = date.minute.toString().padLeft(2, '0');
  final period = date.hour >= 12 ? 'PM' : 'AM';
  return '$h:$minute $period';
}

String formatExpenseDateTime(DateTime date, DateTime now) {
  final timeStr = formatTime(date);
  final startOfToday = DateTime(now.year, now.month, now.day);
  final startOfDate = DateTime(date.year, date.month, date.day);
  if (startOfDate == startOfToday) {
    return timeStr;
  }
  return '$timeStr • ${displayDate(date)}';
}

