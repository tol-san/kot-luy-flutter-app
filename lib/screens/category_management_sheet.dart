import 'package:flutter/material.dart';

import '../data/expense_repository.dart';
import '../models/expense.dart';
import '../theme.dart';

class CategoryManagementSheet extends StatefulWidget {
  const CategoryManagementSheet({
    super.key,
    required this.repository,
    this.onCategoriesChanged,
  });

  final ExpenseRepository repository;
  final ValueChanged<List<ExpenseCategory>>? onCategoriesChanged;

  static Future<List<ExpenseCategory>?> show(
    BuildContext context,
    ExpenseRepository repository,
  ) => showModalBottomSheet<List<ExpenseCategory>>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => CategoryManagementSheet(repository: repository),
  );

  @override
  State<CategoryManagementSheet> createState() => _CategoryManagementSheetState();
}

class _CategoryManagementSheetState extends State<CategoryManagementSheet> {
  final _textController = TextEditingController();
  List<ExpenseCategory> _categories = [];
  bool _loading = true;
  bool _adding = false;

  @override
  void initState() {
    super.initState();
    _loadCategories();
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

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

  Future<void> _addCategory() async {
    final text = _textController.text.trim();
    if (text.isEmpty || _adding) return;
    setState(() => _adding = true);
    try {
      final newCat = await widget.repository.addCategory(text);
      _textController.clear();
      if (mounted) {
        setState(() {
          _categories.add(newCat);
          _adding = false;
        });
        widget.onCategoriesChanged?.call(_categories);
      }
    } catch (_) {
      if (mounted) setState(() => _adding = false);
    }
  }

  Future<void> _deleteCategory(ExpenseCategory category) async {
    if (_categories.length <= 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('មិនអាចលុបបានទេ ត្រូវមានប្រភេទយ៉ាងហោចណាស់មួយ'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('លុបប្រភេទនេះ?'),
        content: Text(
          '«${category.label}» នឹងត្រូវបានលុបចេញពីបញ្ជីប្រភេទចំណាយ។',
        ),
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
            Center(
              child: Container(
                margin: const EdgeInsets.only(top: 12, bottom: 8),
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: line,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 4, 12, 4),
              child: Row(
                children: [
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'រៀបចំប្រភេទចំណាយ',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: ink,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'អូសសញ្ញា ☰ ដើម្បីប្តូរលំដាប់មុខក្រោយ',
                          style: TextStyle(fontSize: 11, color: muted),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    key: const Key('closeCategorySheet'),
                    tooltip: 'បិទ',
                    icon: const Icon(Icons.close_rounded, color: muted),
                    onPressed: () => Navigator.pop(context, _categories),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            // Add Category input
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
              child: SizedBox(
                height: 48,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      child: TextField(
                        key: const Key('addCategoryInput'),
                        controller: _textController,
                        textInputAction: TextInputAction.done,
                        onSubmitted: (_) => _addCategory(),
                        decoration: InputDecoration(
                          hintText: 'បញ្ចូលឈ្មោះប្រភេទថ្មី...',
                          hintStyle: const TextStyle(fontSize: 13, color: muted),
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 12,
                          ),
                          filled: true,
                          fillColor: Colors.white,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: const BorderSide(color: line),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: const BorderSide(color: line),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: const BorderSide(color: green, width: 1.5),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    FilledButton.icon(
                      key: const Key('addCategoryButton'),
                      onPressed: _adding ? null : _addCategory,
                      style: FilledButton.styleFrom(
                        backgroundColor: green,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      icon: _adding
                          ? const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.add_rounded, size: 18),
                      label: const Text(
                        'បន្ថែម',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (_loading)
              const Padding(
                padding: EdgeInsets.all(40),
                child: Center(child: CircularProgressIndicator()),
              )
            else
              Flexible(
                child: ReorderableListView.builder(
                  key: const Key('categoryReorderList'),
                  shrinkWrap: true,
                  buildDefaultDragHandles: false,
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
                  itemCount: _categories.length,
                  onReorderItem: _onReorderItem,
                  itemBuilder: (context, index) {
                    final cat = _categories[index];
                    return Container(
                      key: ValueKey(cat.name),
                      height: 48,
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: line),
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
                              color: cat.color,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              cat.label,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: ink,
                              ),
                            ),
                          ),
                          IconButton(
                            tooltip: 'លុបប្រភេទនេះ',
                            icon: const Icon(
                              Icons.delete_outline_rounded,
                              color: Color(0xFFC26D6D),
                              size: 20,
                            ),
                            onPressed: () => _deleteCategory(cat),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}
