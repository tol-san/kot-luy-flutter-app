import 'dart:async';

import 'package:flutter/material.dart';

import '../data/expense_repository.dart';
import '../models/expense.dart';
import '../theme.dart';
import '../widgets/category_input_row.dart';
import '../widgets/category_list_item.dart';

// ---------------------------------------------------------------------------
// Result type
// ---------------------------------------------------------------------------

class CategoryManagementResult {
  const CategoryManagementResult({
    required this.categories,
    this.selectedCategory,
  });

  final List<ExpenseCategory> categories;
  final ExpenseCategory? selectedCategory;
}

// ---------------------------------------------------------------------------
// Sheet widget
// ---------------------------------------------------------------------------

class CategoryManagementSheet extends StatefulWidget {
  const CategoryManagementSheet({
    super.key,
    required this.repository,
    this.onCategoriesChanged,
  });

  final ExpenseRepository repository;
  final ValueChanged<List<ExpenseCategory>>? onCategoriesChanged;

  static Future<CategoryManagementResult?> show(
    BuildContext context,
    ExpenseRepository repository,
  ) => showModalBottomSheet<CategoryManagementResult>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => CategoryManagementSheet(repository: repository),
  );

  @override
  State<CategoryManagementSheet> createState() =>
      _CategoryManagementSheetState();
}

// ---------------------------------------------------------------------------
// State – owns all business logic; delegates UI to extracted widgets
// ---------------------------------------------------------------------------

class _CategoryManagementSheetState extends State<CategoryManagementSheet> {
  List<ExpenseCategory> _categories = [];
  bool _loading = true;
  bool _adding = false;
  String? _highlightedCategoryId;
  Timer? _highlightTimer;

  // ── Lifecycle ──────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _loadCategories();
  }

  @override
  void dispose() {
    _highlightTimer?.cancel();
    super.dispose();
  }

  void _highlightCategory(String id) {
    _highlightTimer?.cancel();
    setState(() => _highlightedCategoryId = id);
    _highlightTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) setState(() => _highlightedCategoryId = null);
    });
  }

  void _highlightCategoryByName(String name) {
    final clean = name.trim().toLowerCase();
    for (final c in _categories) {
      if (c.label.trim().toLowerCase() == clean) {
        _highlightCategory(c.name);
        break;
      }
    }
  }

  // ── Data helpers ──────────────────────────────────────────────────────────

  Future<void> _loadCategories() async {
    final list = await widget.repository.getCategories();
    if (mounted) {
      setState(() {
        _categories = List.of(list);
        _loading = false;
      });
      widget.onCategoriesChanged?.call(_categories);
    }
  }

  void _selectCategory(ExpenseCategory category) {
    if (_adding) return;
    Navigator.pop(
      context,
      CategoryManagementResult(
        categories: _categories,
        selectedCategory: category,
      ),
    );
  }

  Future<void> _addCategory(String name) async {
    final cleanName = name.trim();
    if (cleanName.isEmpty) return;
    if (_adding) return;

    if (_categories.any(
      (c) => c.label.trim().toLowerCase() == cleanName.toLowerCase(),
    )) {
      _highlightCategoryByName(cleanName);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'មុខចំណាយ «$cleanName» មានរួចហើយ មិនអាចបន្ថែមស្ទួនបានទេ',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() => _adding = true);
    try {
      final newCat = await widget.repository.addCategory(cleanName);
      _categories.add(newCat);
      widget.onCategoriesChanged?.call(_categories);
      if (mounted) {
        Navigator.pop(
          context,
          CategoryManagementResult(
            categories: _categories,
            selectedCategory: newCat,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _adding = false);
        final message = e is ArgumentError && e.message != null
            ? e.message.toString()
            : 'មិនអាចបន្ថែមមុខចំណាយនេះបានទេ';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
        );
      }
    }
  }

  Future<void> _deleteCategory(ExpenseCategory category) async {
    if (_categories.length <= 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('មិនអាចលុបបានទេ ត្រូវមានមុខចំណាយយ៉ាងហោចណាស់មួយ'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('លុបមុខចំណាយនេះ?'),
        content: Text('«${category.label}» នឹងត្រូវបានលុបចេញពីបញ្ជីមុខចំណាយ។'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('ទុកវិញ'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              'លុប',
              style: TextStyle(color: Color(0xFFAD5347)),
            ),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await widget.repository.deleteCategory(category.name);
      await _loadCategories();
    }
  }

  void _onReorderItem(int oldIndex, int newIndex) {
    setState(() {
      final item = _categories.removeAt(oldIndex);
      _categories.insert(newIndex, item);
    });
    final ids = _categories.map((c) => c.name).toList();
    widget.repository.reorderCategories(ids);
    widget.onCategoriesChanged?.call(_categories);
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.82,
      ),
      padding: EdgeInsets.only(bottom: bottomInset),
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
            _buildDragHandle(),
            _buildHeader(),
            const Divider(height: 1),
            CategoryInputRow(
              onAdd: _addCategory,
              existingCategories: _categories,
              onSelectExisting: _selectCategory,
              isAdding: _adding,
            ),
            _loading ? _buildLoader() : _buildList(),
          ],
        ),
      ),
    );
  }

  // ── Private UI helpers ────────────────────────────────────────────────────

  Widget _buildDragHandle() => Center(
    child: Container(
      margin: const EdgeInsets.only(top: 12, bottom: 8),
      width: 36,
      height: 4,
      decoration: BoxDecoration(
        color: line,
        borderRadius: BorderRadius.circular(2),
      ),
    ),
  );

  Widget _buildHeader() => Padding(
    padding: const EdgeInsets.fromLTRB(22, 4, 12, 4),
    child: Row(
      children: [
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'រៀបចំមុខចំណាយ',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: ink,
                ),
              ),
              SizedBox(height: 2),
              Text(
                'ចុចដើម្បីជ្រើសរើស • អូសសញ្ញា ☰ ដើម្បីប្តូរលំដាប់',
                style: TextStyle(fontSize: 11, color: muted),
              ),
            ],
          ),
        ),
        IconButton(
          key: const Key('closeCategorySheet'),
          tooltip: 'បិទ',
          icon: const Icon(Icons.close_rounded, color: muted),
          onPressed: () => Navigator.pop(
            context,
            CategoryManagementResult(
              categories: _categories,
              selectedCategory: null,
            ),
          ),
        ),
      ],
    ),
  );

  Widget _buildLoader() => const Padding(
    padding: EdgeInsets.all(40),
    child: Center(child: CircularProgressIndicator()),
  );

  Widget _buildList() => Flexible(
    child: ReorderableListView.builder(
      key: const Key('categoryReorderList'),
      shrinkWrap: true,
      buildDefaultDragHandles: false,
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
      itemCount: _categories.length,
      onReorderItem: _onReorderItem,
      itemBuilder: (_, index) => CategoryListItem(
        key: ValueKey(_categories[index].name),
        category: _categories[index],
        index: index,
        isHighlighted: _categories[index].name == _highlightedCategoryId,
        onSelect: _adding ? null : () => _selectCategory(_categories[index]),
        onDelete: () => _deleteCategory(_categories[index]),
      ),
    ),
  );
}
