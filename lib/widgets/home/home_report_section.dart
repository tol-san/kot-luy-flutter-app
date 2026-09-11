import 'package:flutter/material.dart';

import 'package:kot_luy/models/expense.dart';
import 'package:kot_luy/theme.dart';

class HomeReportSection extends StatelessWidget {
  const HomeReportSection({
    super.key,
    required this.expenses,
    required this.categories,
    required this.onPdfExport,
    required this.companion,
  });

  final List<Expense> expenses;
  final List<ExpenseCategory> categories;
  final VoidCallback onPdfExport;
  final Widget companion;

  @override
  Widget build(BuildContext context) {
    final total = expenses.fold(0, (sum, expense) => sum + expense.amount);
    final presentCategories = <String, ExpenseCategory>{
      for (final category in categories) category.name: category,
      for (final expense in expenses) expense.category.name: expense.category,
    };
    final categoryTotals = {
      for (final category in presentCategories.values)
        category: expenses
            .where((expense) => expense.category.name == category.name)
            .fold(0, (sum, expense) => sum + expense.amount),
    };
    final sortedTotals =
        categoryTotals.entries.where((entry) => entry.value > 0).toList()
          ..sort((a, b) => b.value.compareTo(a.value));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'ចំណាយតាមមុខចំណាយ',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            FilledButton.tonalIcon(
              key: const ValueKey('pdfExportReportButton'),
              style: FilledButton.styleFrom(
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
              ),
              icon: const Icon(Icons.picture_as_pdf_rounded, size: 16),
              label: const Text('ទាញយក PDF', style: TextStyle(fontSize: 12)),
              onPressed: onPdfExport,
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (total == 0)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 40),
            child: Center(
              child: Text(
                'កត់ចំណាយដំបូង ដើម្បីមើលរបាយការណ៍។',
                style: TextStyle(color: muted, fontSize: 12),
              ),
            ),
          ),
        ...sortedTotals.map(
          (entry) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 14),
            child: Column(
              children: [
                Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: entry.key.color,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        entry.key.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 13),
                      ),
                    ),
                    Text(
                      riel(entry.value),
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      '${(entry.value / total * 100).toStringAsFixed(1)}%',
                      style: const TextStyle(color: muted, fontSize: 11),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(5),
                  child: LinearProgressIndicator(
                    value: entry.value / total,
                    backgroundColor: entry.key.background,
                    color: entry.key.color,
                    minHeight: 7,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),
        companion,
      ],
    );
  }
}
