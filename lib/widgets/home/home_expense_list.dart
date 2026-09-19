import 'package:clock/clock.dart';
import 'package:flutter/material.dart';

import 'package:kot_luy/data/expense_repository.dart';
import 'package:kot_luy/models/expense.dart';
import 'package:kot_luy/screens/detail_screen.dart';
import 'package:kot_luy/theme.dart';

class HomeExpenseList extends StatelessWidget {
  const HomeExpenseList({
    super.key,
    required this.expenses,
    required this.repository,
    required this.hasAnyExpenses,
    required this.query,
    required this.category,
    required this.isSelecting,
    required this.selectedIds,
    required this.onToggleSelect,
    required this.onLongPress,
    required this.onLoaded,
  });

  final ExpenseRepository repository;
  final List<Expense> expenses;
  final bool hasAnyExpenses;
  final String query;
  final ExpenseCategory? category;
  final bool isSelecting;
  final Set<int> selectedIds;
  final ValueChanged<int> onToggleSelect;
  final ValueChanged<int> onLongPress;
  final VoidCallback onLoaded;

  @override
  Widget build(BuildContext context) {
    final items = expenses;
    if (items.isEmpty) {
      return SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 22, 24, 16),
          child: Column(
            children: [
              Icon(
                query.isNotEmpty || category != null
                    ? Icons.search_off_rounded
                    : Icons.receipt_long_outlined,
                color: const Color(0xFFA8B29B),
                size: 36,
              ),
              const SizedBox(height: 10),
              Text(
                !hasAnyExpenses
                    ? 'ចាប់ផ្ដើមទំព័រថ្មីរបស់អ្នក'
                    : 'មិនមានចំណាយក្នុងជម្រើសនេះ',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 5),
              Text(
                !hasAnyExpenses
                    ? 'ចុច «កត់ចំណាយ» ដើម្បីបន្ថែមចំណាយដំបូង។'
                    : 'សាកប្ដូររយៈពេល ឬពាក្យស្វែងរក។',
                style: const TextStyle(color: muted, fontSize: 11),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      sliver: SliverList.builder(
        itemCount: items.length,
        itemBuilder: (context, index) {
          final e = items[index];
          final isSelected = e.id != null && selectedIds.contains(e.id);
          return Column(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                decoration: BoxDecoration(
                  color: isSelected
                      ? const Color(0xFFF0F4E8)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    key: Key('expense_item_${e.id}'),
                    borderRadius: BorderRadius.circular(12),
                    onLongPress: () {
                      if (e.id != null) onLongPress(e.id!);
                    },
                    onTap: () async {
                      if (isSelecting) {
                        if (e.id != null) onToggleSelect(e.id!);
                        return;
                      }
                      await Navigator.push(
                        context,
                        MaterialPageRoute<void>(
                          builder: (_) => DetailScreen(
                            expense: e,
                            repository: repository,
                          ),
                        ),
                      );
                      onLoaded();
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        vertical: 14,
                        horizontal: 8,
                      ),
                      child: Row(
                        children: [
                          if (isSelecting) ...[
                            Icon(
                              isSelected
                                  ? Icons.check_circle_rounded
                                  : Icons.radio_button_unchecked_rounded,
                              color: isSelected ? green : muted,
                              size: 22,
                            ),
                            const SizedBox(width: 10),
                          ],
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  e.category.label,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 15,
                                    color: ink,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  formatExpenseDateTime(e.date, clock.now()),
                                  style: const TextStyle(
                                    color: muted,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            riel(e.amount),
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: ink,
                            ),
                          ),
                          if (!isSelecting) ...[
                            const SizedBox(width: 6),
                            const Icon(
                              Icons.chevron_right_rounded,
                              color: Color(0xFFB2B8AC),
                              size: 18,
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              const Divider(height: 1, color: line),
            ],
          );
        },
      ),
    );
  }
}
