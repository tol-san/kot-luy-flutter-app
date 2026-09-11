import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class ExpenseCategory {
  static const maxLabelLength = 40;

  const ExpenseCategory({
    required this.name,
    required this.label,
    required this.icon,
    required this.color,
    required this.background,
    this.isCustom = false,
    this.isArchived = false,
  });

  final String name;
  final String label;
  final IconData icon;
  final Color color;
  final Color background;
  final bool isCustom;
  final bool isArchived;

  static const breakfast = ExpenseCategory(
    name: 'breakfast',
    label: 'បាយពេលព្រឹក',
    icon: Icons.wb_sunny_outlined,
    color: Color(0xFF2563EB),
    background: Color(0xFFE8EFFE),
  );
  static const lunch = ExpenseCategory(
    name: 'lunch',
    label: 'បាយថ្ងៃត្រង់',
    icon: Icons.restaurant_rounded,
    color: Color(0xFF16A34A),
    background: Color(0xFFE7F5EC),
  );
  static const dinner = ExpenseCategory(
    name: 'dinner',
    label: 'បាយល្ងាច',
    icon: Icons.nights_stay_outlined,
    color: Color(0xFFDC2626),
    background: Color(0xFFFCE8E8),
  );
  static const fuel = ExpenseCategory(
    name: 'fuel',
    label: 'ចាក់សាំង',
    icon: Icons.local_gas_station_rounded,
    color: Color(0xFFEAB308),
    background: Color(0xFFFEF7DC),
  );
  static const coffee = ExpenseCategory(
    name: 'coffee',
    label: 'កាហ្វេ',
    icon: Icons.local_cafe_outlined,
    color: Color(0xFF9333EA),
    background: Color(0xFFF3E9FD),
  );
  static const other = ExpenseCategory(
    name: 'other',
    label: 'ផ្សេងៗ',
    icon: Icons.more_horiz_rounded,
    color: Color(0xFF64748B),
    background: Color(0xFFEEF1F5),
  );

  static const List<ExpenseCategory> values = [
    breakfast,
    lunch,
    dinner,
    fuel,
    coffee,
  ];

  /// 30 distinct colors spanning diverse hue families.
  static const List<Color> autoColors = [
    Color(0xFF2563EB), // 1. Blue (Breakfast)
    Color(0xFF16A34A), // 2. Green (Lunch)
    Color(0xFFDC2626), // 3. Red (Dinner)
    Color(0xFFEAB308), // 4. Yellow (Fuel)
    Color(0xFF9333EA), // 5. Purple (Coffee)
    Color(0xFFEA580C), // 6. Orange
    Color(0xFF0891B2), // 7. Cyan
    Color(0xFFDB2777), // 8. Pink
    Color(0xFF795548), // 9. Brown
    Color(0xFF64748B), // 10. Slate
    Color(0xFF65A30D), // 11. Lime
    Color(0xFF0D9488), // 12. Teal
    Color(0xFF4F46E5), // 13. Indigo
    Color(0xFFE11D48), // 14. Rose
    Color(0xFFD97706), // 15. Amber
    Color(0xFF059669), // 16. Emerald
    Color(0xFF7C3AED), // 17. Violet
    Color(0xFF0284C7), // 18. Sky Blue
    Color(0xFFF97316), // 19. Coral Orange
    Color(0xFF84CC16), // 20. Chartreuse
    Color(0xFF06B6D4), // 21. Turquoise
    Color(0xFFA855F7), // 22. Lavender
    Color(0xFFF43F5E), // 23. Crimson
    Color(0xFF854D0E), // 24. Ochre
    Color(0xFF475569), // 25. Charcoal Slate
    Color(0xFF10B981), // 26. Mint
    Color(0xFF3B82F6), // 27. Bright Blue
    Color(0xFFC026D3), // 28. Fuchsia
    Color(0xFFB45309), // 29. Bronze
    Color(0xFF14B8A6), // 30. Aquamarine
  ];

  /// Use unused colors first, then reuse the least common color.
  /// Include archived categories so restoring one keeps its assigned color.
  static Color nextColor(Iterable<Color> usedColors) {
    final counts = <int, int>{};
    for (final color in usedColors) {
      counts.update(color.toARGB32(), (count) => count + 1, ifAbsent: () => 1);
    }
    return autoColors.reduce(
      (best, color) =>
          (counts[color.toARGB32()] ?? 0) < (counts[best.toARGB32()] ?? 0)
          ? color
          : best,
    );
  }

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
