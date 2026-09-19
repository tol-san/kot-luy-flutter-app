import 'package:flutter/material.dart';

import 'package:kot_luy/theme.dart';

class HomeListHeader extends StatelessWidget {
  const HomeListHeader({
    super.key,
    required this.canEnterSelection,
    required this.isSearchActive,
    required this.isCategoryFiltered,
    required this.onEnterSelection,
    required this.onToggleSearch,
    required this.onCategoryFilter,
  });

  final bool canEnterSelection;
  final bool isSearchActive;
  final bool isCategoryFiltered;
  final VoidCallback onEnterSelection;
  final VoidCallback onToggleSearch;
  final VoidCallback onCategoryFilter;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      const Expanded(
        child: Text(
          'បញ្ជីចំណាយ',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
        ),
      ),
      IconButton(
        key: const Key('enterSelectionModeButton'),
        tooltip: 'ជ្រើសរើសច្រើន',
        onPressed: canEnterSelection ? onEnterSelection : null,
        icon: const Icon(Icons.checklist_rounded, color: ink, size: 22),
      ),
      IconButton(
        tooltip: 'ស្វែងរកចំណាយ',
        onPressed: onToggleSearch,
        icon: Icon(
          isSearchActive ? Icons.search_off : Icons.search_rounded,
          color: ink,
          size: 23,
        ),
      ),
      IconButton(
        key: const Key('categoryFilterButton'),
        tooltip: 'ច្រោះតាមមុខចំណាយ',
        onPressed: onCategoryFilter,
        icon: Icon(
          Icons.tune_rounded,
          color: isCategoryFiltered ? green : muted,
          size: 22,
        ),
      ),
    ],
  );
}
