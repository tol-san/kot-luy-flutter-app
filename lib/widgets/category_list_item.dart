import 'package:flutter/material.dart';

import '../models/expense.dart';
import '../theme.dart';

/// A single row in the category reorderable list.
///
/// Displays the drag handle, colour dot, label, and delete button.
/// All actions are delegated to callbacks so this widget is purely presentational.
class CategoryListItem extends StatelessWidget {
  const CategoryListItem({
    super.key,
    required this.category,
    required this.index,
    required this.onDelete,
    this.isHighlighted = false,
  });

  final ExpenseCategory category;
  final int index;
  final VoidCallback onDelete;
  final bool isHighlighted;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      key: ValueKey(category.name),
      height: 48,
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: isHighlighted ? const Color(0xFFFDE8E8) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isHighlighted ? const Color(0xFFC26D6D) : line,
          width: isHighlighted ? 1.5 : 1,
        ),
      ),
      child: Row(
        children: [
          ReorderableDragStartListener(
            index: index,
            child: const Padding(
              padding: EdgeInsets.only(right: 12),
              child: Icon(
                Icons.drag_handle_rounded,
                color: muted,
                size: 20,
              ),
            ),
          ),
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              color: category.color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              category.label,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: ink,
              ),
            ),
          ),
          IconButton(
            tooltip: 'លុបមុខចំណាយនេះ',
            icon: const Icon(
              Icons.delete_outline_rounded,
              color: Color(0xFFC26D6D),
              size: 20,
            ),
            onPressed: onDelete,
          ),
        ],
      ),
    );
  }
}
