import 'package:flutter/material.dart';

import 'package:kot_luy/theme.dart';

class HomeSelectionBar extends StatelessWidget {
  const HomeSelectionBar({
    super.key,
    required this.selectedCount,
    required this.totalCount,
    required this.onCancel,
    required this.onToggleAll,
    required this.onDelete,
  });

  final int selectedCount;
  final int totalCount;
  final VoidCallback onCancel;
  final VoidCallback onToggleAll;
  final VoidCallback? onDelete;

  bool get _allSelected => selectedCount == totalCount && totalCount > 0;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      IconButton(
        key: const Key('cancelSelectionButton'),
        tooltip: 'បោះបង់',
        onPressed: onCancel,
        icon: const Icon(Icons.close_rounded, color: ink),
      ),
      const SizedBox(width: 4),
      Expanded(
        child: Text(
          selectedCount == 0 ? 'ជ្រើសរើសចំណាយ' : 'បានជ្រើសរើស $selectedCount',
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: ink,
          ),
        ),
      ),
      IconButton(
        key: const Key('selectAllButton'),
        tooltip: _allSelected ? 'ដោះជម្រើសទាំងអស់' : 'ជ្រើសរើសទាំងអស់',
        icon: Icon(
          _allSelected ? Icons.deselect_rounded : Icons.select_all_rounded,
          color: ink,
          size: 22,
        ),
        onPressed: onToggleAll,
      ),
      IconButton(
        key: const Key('deleteSelectedExpensesButton'),
        tooltip: 'លុប',
        icon: Icon(
          Icons.delete_outline_rounded,
          color: selectedCount == 0 ? muted : const Color(0xFFAD5347),
          size: 22,
        ),
        onPressed: selectedCount == 0 ? null : onDelete,
      ),
    ],
  );
}
