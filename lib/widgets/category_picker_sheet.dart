import 'package:flutter/material.dart';

import 'package:kot_luy/models/expense.dart';
import 'package:kot_luy/theme.dart';

class CategoryPickerSheet extends StatelessWidget {
  const CategoryPickerSheet({
    super.key,
    required this.categories,
    required this.selectedCategory,
    required this.onManageCategories,
  });

  final List<ExpenseCategory> categories;
  final ExpenseCategory selectedCategory;
  final Future<void> Function() onManageCategories;

  static Future<ExpenseCategory?> show(
    BuildContext context, {
    required List<ExpenseCategory> categories,
    required ExpenseCategory selectedCategory,
    required Future<void> Function() onManageCategories,
  }) => showModalBottomSheet<ExpenseCategory>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => CategoryPickerSheet(
      categories: categories,
      selectedCategory: selectedCategory,
      onManageCategories: onManageCategories,
    ),
  );

  @override
  Widget build(BuildContext context) => Container(
    constraints: BoxConstraints(
      maxHeight: MediaQuery.sizeOf(context).height * 0.75,
    ),
    decoration: const BoxDecoration(
      color: paper,
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    child: SafeArea(
      top: false,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 10, bottom: 8),
              width: 44,
              height: 4,
              decoration: BoxDecoration(
                color: line,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 6, 12, 6),
            child: Row(
              children: [
                const Expanded(
                  child: Text(
                    'ជ្រើសរើសមុខចំណាយ',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: ink,
                    ),
                  ),
                ),
                IconButton(
                  key: const Key('closeCategoryPicker'),
                  icon: const Icon(Icons.close_rounded, color: muted),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Flexible(
            child: ListView.builder(
              shrinkWrap: true,
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              itemCount: categories.length,
              itemBuilder: (context, index) {
                final category = categories[index];
                final isSelected = category == selectedCategory;
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Material(
                    color: isSelected ? category.background : Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                      side: BorderSide(
                        color: isSelected ? category.color : line,
                        width: isSelected ? 1.5 : 1,
                      ),
                    ),
                    child: ListTile(
                      key: Key('picker_category_${category.name}'),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      leading: Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          color: category.color,
                          shape: BoxShape.circle,
                        ),
                      ),
                      title: Text(
                        category.label,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: isSelected
                              ? FontWeight.w700
                              : FontWeight.w600,
                          color: isSelected ? category.color : ink,
                        ),
                      ),
                      trailing: isSelected
                          ? Icon(
                              Icons.check_circle_rounded,
                              color: category.color,
                              size: 20,
                            )
                          : null,
                      onTap: () => Navigator.pop(context, category),
                    ),
                  ),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12),
                side: const BorderSide(color: green),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              icon: const Icon(Icons.swap_vert_rounded, size: 18, color: green),
              label: const Text(
                'រៀបចំ ឬ បន្ថែមមុខចំណាយថ្មី',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: green,
                ),
              ),
              onPressed: () async {
                Navigator.pop(context);
                await onManageCategories();
              },
            ),
          ),
        ],
      ),
    ),
  );
}
