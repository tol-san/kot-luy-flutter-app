import 'package:flutter/material.dart';

import 'package:kot_luy/models/expense.dart';
import 'package:kot_luy/theme.dart';

/// Grid of category buttons (top-5 + "more") shown in the expense form.
class CategorySelector extends StatelessWidget {
  const CategorySelector({
    super.key,
    required this.categories,
    required this.selected,
    required this.onSelect,
    required this.onMore,
    required this.onManage,
  });

  final List<ExpenseCategory> categories;
  final ExpenseCategory selected;
  final ValueChanged<ExpenseCategory> onSelect;
  final VoidCallback onMore;
  final VoidCallback onManage;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text(
              'មុខចំណាយ',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            const Spacer(),
            InkWell(
              key: const Key('manageCategoriesButton'),
              borderRadius: BorderRadius.circular(8),
              onTap: onManage,
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.swap_vert_rounded, size: 16, color: green),
                    SizedBox(width: 4),
                    Text(
                      'រៀបចំ ឬ បន្ថែម',
                      style: TextStyle(
                        fontSize: 12,
                        color: green,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        LayoutBuilder(
          builder: (context, constraints) {
            final buttonWidth = (constraints.maxWidth - 16) / 3;
            final top5 = categories.take(5).toList();
            final isCategoryInTop5 = top5.contains(selected);
            final moreButtonLabel =
                !isCategoryInTop5 ? selected.label : 'ច្រើនទៀត';
            final isMoreSelected = !isCategoryInTop5;
            final moreCategory = !isCategoryInTop5 ? selected : null;

            return Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final c in top5)
                  SizedBox(
                    width: buttonWidth,
                    child: Semantics(
                      selected: c == selected,
                      child: Material(
                        color: c == selected ? c.background : Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                          side: BorderSide(
                            color: c == selected ? c.color : line,
                            width: c == selected ? 1.5 : 1,
                          ),
                        ),
                        child: InkWell(
                          key: Key('category_${c.name}'),
                          borderRadius: BorderRadius.circular(14),
                          onTap: () => onSelect(c),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              vertical: 13,
                              horizontal: 4,
                            ),
                            child: Center(
                              child: Text(
                                c.label,
                                textAlign: TextAlign.center,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: c == selected
                                      ? FontWeight.w700
                                      : FontWeight.w500,
                                  color: c == selected ? c.color : ink,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                SizedBox(
                  width: buttonWidth,
                  child: Semantics(
                    selected: isMoreSelected,
                    child: Material(
                      color: isMoreSelected
                          ? (moreCategory?.background ??
                                const Color(0xFFF0F2EB))
                          : Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                        side: BorderSide(
                          color: isMoreSelected
                              ? (moreCategory?.color ?? green)
                              : line,
                          width: isMoreSelected ? 1.5 : 1,
                        ),
                      ),
                      child: InkWell(
                        key: const Key('category_more'),
                        borderRadius: BorderRadius.circular(14),
                        onTap: onMore,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            vertical: 13,
                            horizontal: 4,
                          ),
                          child: Center(
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Flexible(
                                  child: Text(
                                    moreButtonLabel,
                                    textAlign: TextAlign.center,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: isMoreSelected
                                          ? FontWeight.w700
                                          : FontWeight.w500,
                                      color: isMoreSelected
                                          ? (moreCategory?.color ?? green)
                                          : muted,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 2),
                                Icon(
                                  Icons.expand_more_rounded,
                                  size: 14,
                                  color: isMoreSelected
                                      ? (moreCategory?.color ?? green)
                                      : muted,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ],
    );
  }
}
