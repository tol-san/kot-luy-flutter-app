import 'package:flutter/material.dart';

import 'package:kot_luy/formatters/khmer_number_words.dart';
import 'package:kot_luy/models/expense.dart';
import 'package:kot_luy/theme.dart';
import 'package:kot_luy/widgets/expense_chart.dart';

class HomeSummaryCard extends StatelessWidget {
  const HomeSummaryCard({
    super.key,
    required this.expenses,
    required this.categories,
    required this.period,
    this.periodLabel,
    required this.onOpenReports,
  });

  final List<Expense> expenses;
  final List<ExpenseCategory> categories;
  final ExpensePeriod period;
  final String? periodLabel;
  final VoidCallback onOpenReports;

  @override
  Widget build(BuildContext context) {
    final total = expenses.fold(0, (a, e) => a + e.amount);
    final presentCategories = <String, ExpenseCategory>{
      for (final e in expenses) e.category.name: e.category,
    };
    final orderedCategories = categories
        .where((c) => presentCategories.containsKey(c.name))
        .toList();
    for (final c in presentCategories.values) {
      if (!orderedCategories.any((x) => x.name == c.name)) {
        orderedCategories.add(c);
      }
    }

    return Container(
      key: const Key('summaryCard'),
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: line),
        borderRadius: BorderRadius.circular(25),
      ),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'ចំណាយសរុប',
                      style: TextStyle(color: muted, fontSize: 12),
                    ),
                    const SizedBox(height: 7),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        riel(total),
                        key: const Key('totalAmount'),
                        style: const TextStyle(
                          fontSize: 31,
                          height: 1.35,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -1,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              InkWell(
                borderRadius: BorderRadius.circular(80),
                onTap: onOpenReports,
                child: ExpenseChart(
                  expenses: expenses,
                  size: MediaQuery.sizeOf(context).width < 370 ? 88 : 104,
                ),
              ),
            ],
          ),
          const SizedBox(height: 5),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              khmerRielWords(total),
              key: const Key('totalAmountWords'),
              softWrap: true,
              style: const TextStyle(
                color: muted,
                fontSize: 11.5,
                height: 1.55,
              ),
            ),
          ),
          const SizedBox(height: 5),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              '${expenses.length} កំណត់ត្រា • ${periodLabel ?? period.label}',
              style: const TextStyle(fontSize: 10, color: muted),
            ),
          ),
          if (orderedCategories.isNotEmpty) ...[
            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 14),
            _CategoryLegend(
              categories: orderedCategories,
              onShowAll: (cats) => _showAllCategories(context, cats),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _showAllCategories(
    BuildContext context,
    List<ExpenseCategory> cats,
  ) => showModalBottomSheet<void>(
    context: context,
    useSafeArea: true,
    showDragHandle: true,
    backgroundColor: paper,
    constraints: const BoxConstraints(maxWidth: 560),
    builder: (sheetContext) => ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(sheetContext).height * 0.6,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 8, 8),
            child: Row(
              children: [
                const Expanded(
                  child: Text(
                    'មុខចំណាយទាំងអស់',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                  ),
                ),
                IconButton(
                  tooltip: 'បិទ',
                  onPressed: () => Navigator.pop(sheetContext),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Flexible(
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
              shrinkWrap: true,
              itemCount: cats.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (_, index) {
                final category = cats[index];
                return Row(
                  key: Key('allCategory_${category.name}'),
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: category.color,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        category.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    ),
  );
}

class _CategoryLegend extends StatelessWidget {
  const _CategoryLegend({required this.categories, required this.onShowAll});

  final List<ExpenseCategory> categories;
  final void Function(List<ExpenseCategory>) onShowAll;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const spacing = 16.0;
        const runSpacing = 8.0;
        final textDirection = Directionality.of(context);
        final textScaler = MediaQuery.textScalerOf(context);
        final inheritedStyle = DefaultTextStyle.of(context).style;
        final labelStyle = inheritedStyle.merge(
          const TextStyle(fontSize: 10, color: muted),
        );
        final moreStyle = inheritedStyle.merge(
          const TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            color: green,
          ),
        );

        double textWidth(String text, TextStyle style) {
          final painter = TextPainter(
            text: TextSpan(text: text, style: style),
            textDirection: textDirection,
            textScaler: textScaler,
            maxLines: 1,
          )..layout(maxWidth: constraints.maxWidth);
          return painter.width;
        }

        double itemWidth(ExpenseCategory category) =>
            (11 + textWidth(category.label, labelStyle)).clamp(
              0,
              constraints.maxWidth,
            );

        double moreWidth(int count) => (4 + textWidth('+$count ទៀត', moreStyle))
            .clamp(0, constraints.maxWidth);

        bool fitsInTwoRuns(List<double> widths) {
          var runs = 1;
          var usedWidth = 0.0;
          for (final width in widths) {
            final needed = usedWidth == 0 ? width : spacing + width;
            if (usedWidth + needed <= constraints.maxWidth + 0.01) {
              usedWidth += needed;
            } else {
              runs++;
              usedWidth = width;
              if (runs > 2) return false;
            }
          }
          return true;
        }

        final visible = <ExpenseCategory>[];
        for (var i = 0; i < categories.length; i++) {
          final candidate = [...visible, categories[i]];
          final remaining = categories.length - candidate.length;
          final widths = candidate.map(itemWidth).toList();
          if (remaining > 0) widths.add(moreWidth(remaining));
          if (!fitsInTwoRuns(widths)) break;
          visible.add(categories[i]);
        }
        final remainingCount = categories.length - visible.length;

        Widget legendItem(ExpenseCategory category) => SizedBox(
          key: Key('summaryLegend_${category.name}'),
          width: itemWidth(category),
          child: Row(
            children: [
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  color: category.color,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 5),
              Expanded(
                child: Tooltip(
                  message: category.label,
                  child: Text(
                    category.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: labelStyle,
                  ),
                ),
              ),
            ],
          ),
        );

        return Wrap(
          spacing: spacing,
          runSpacing: runSpacing,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            ...visible.map(legendItem),
            if (remainingCount > 0)
              SizedBox(
                width: moreWidth(remainingCount),
                child: InkWell(
                  key: const Key('expandCategoriesButton'),
                  borderRadius: BorderRadius.circular(6),
                  onTap: () => onShowAll(categories),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 2,
                      vertical: 1,
                    ),
                    child: Text(
                      '+$remainingCount ទៀត',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: moreStyle,
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
