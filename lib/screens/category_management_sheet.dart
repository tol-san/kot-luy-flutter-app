import 'dart:async';

import 'package:flutter/material.dart';

import 'package:kot_luy/data/expense_repository.dart';
import 'package:kot_luy/models/expense.dart';
import 'package:kot_luy/theme.dart';
import 'package:kot_luy/widgets/category_input_row.dart';
import 'package:kot_luy/widgets/category_list_item.dart';

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
  List<ExpenseCategory> _archivedCategories = [];
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
    final list = await widget.repository.getCategories(includeArchived: true);
    if (mounted) {
      setState(() {
        _categories = list.where((c) => !c.isArchived).toList();
        _archivedCategories = list.where((c) => c.isArchived).toList();
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

  Future<void> _renameCategory(ExpenseCategory category) async {
    final renamed = await showDialog<String>(
      context: context,
      builder: (_) => _RenameCategoryDialog(
        category: category,
        categories: [..._categories, ..._archivedCategories],
      ),
    );
    if (renamed == null || !mounted) return;

    try {
      await widget.repository.renameCategory(category.name, renamed);
      await _loadCategories();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            error is ArgumentError && error.message != null
                ? error.message.toString()
                : 'មិនអាចកែឈ្មោះមុខចំណាយបានទេ សូមព្យាយាមម្ដងទៀត',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
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
    bool used;
    try {
      used = await widget.repository.categoryHasExpenses(category.name);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('មិនអាចពិនិត្យមុខចំណាយបានទេ សូមព្យាយាមម្ដងទៀត'),
        ),
      );
      return;
    }
    if (!mounted) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(used ? 'លាក់មុខចំណាយនេះ?' : 'លុបមុខចំណាយនេះ?'),
        content: Text(
          used
              ? 'លាក់មុខចំណាយ «${category.label}»? កំណត់ត្រាចាស់ និងរបាយការណ៍សង្ខេបនឹងនៅដដែល។ មុខចំណាយនេះនឹងលែងបង្ហាញពេលបន្ថែមចំណាយថ្មី។'
              : '«${category.label}» នឹងត្រូវបានលុបជាអចិន្ត្រៃយ៍។',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('ទុកវិញ'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              used ? 'លាក់' : 'លុប',
              style: TextStyle(color: Color(0xFFAD5347)),
            ),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      try {
        await widget.repository.deleteCategory(category.name);
        await _loadCategories();
      } catch (error) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              error is StateError
                  ? error.message
                  : 'មិនអាចលុបមុខចំណាយនេះបានទេ សូមព្យាយាមម្ដងទៀត',
            ),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
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

  Future<void> _restoreCategory(ExpenseCategory category) async {
    try {
      await widget.repository.restoreCategory(category.name);
      await _loadCategories();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('មិនអាចបង្ហាញមុខចំណាយឡើងវិញបានទេ សូមព្យាយាមម្ដងទៀត'),
        ),
      );
    }
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
      footer: _archivedCategories.isEmpty
          ? null
          : Material(
              color: paper,
              child: ExpansionTile(
                shape: const Border(),
                collapsedShape: const Border(),
                title: Text(
                  'មុខចំណាយដែលបានលាក់ (${_archivedCategories.length})',
                ),
                children: _archivedCategories
                    .map(
                      (category) => Padding(
                        key: ValueKey('archived_category_${category.name}'),
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
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
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 14,
                                  height: 1.6,
                                  color: ink,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            TextButton(
                              onPressed: () => _restoreCategory(category),
                              child: const Text('បង្ហាញឡើងវិញ'),
                            ),
                          ],
                        ),
                      ),
                    )
                    .toList(),
              ),
            ),
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
      itemCount: _categories.length,
      onReorderItem: _onReorderItem,
      itemBuilder: (_, index) => CategoryListItem(
        key: ValueKey(_categories[index].name),
        category: _categories[index],
        index: index,
        isHighlighted: _categories[index].name == _highlightedCategoryId,
        onSelect: _adding ? null : () => _selectCategory(_categories[index]),
        onRename: () => _renameCategory(_categories[index]),
        onDelete: () => _deleteCategory(_categories[index]),
      ),
    ),
  );
}

class _RenameCategoryDialog extends StatefulWidget {
  const _RenameCategoryDialog({
    required this.category,
    required this.categories,
  });

  final ExpenseCategory category;
  final List<ExpenseCategory> categories;

  @override
  State<_RenameCategoryDialog> createState() => _RenameCategoryDialogState();
}

class _RenameCategoryDialogState extends State<_RenameCategoryDialog> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.category.label,
  );

  @override
  void initState() {
    super.initState();
    _controller.addListener(_rebuild);
  }

  void _rebuild() => setState(() {});

  @override
  void dispose() {
    _controller.removeListener(_rebuild);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final clean = _controller.text.trim();
    final unchanged = clean == widget.category.label;
    final duplicate = widget.categories.any(
      (item) =>
          item.name != widget.category.name &&
          item.label.trim().toLowerCase() == clean.toLowerCase(),
    );
    final hasEmoji = ExpenseCategory.containsEmoji(clean);
    final canSave = clean.isNotEmpty && !unchanged && !duplicate && !hasEmoji;

    return AlertDialog(
      title: const Text('កែឈ្មោះមុខចំណាយ'),
      content: TextField(
        key: const Key('renameCategoryInput'),
        controller: _controller,
        autofocus: true,
        maxLength: ExpenseCategory.maxLabelLength,
        textInputAction: TextInputAction.done,
        onSubmitted: canSave ? (_) => Navigator.pop(context, clean) : null,
        decoration: InputDecoration(
          labelText: 'ឈ្មោះមុខចំណាយ',
          errorText: hasEmoji
              ? ExpenseCategory.emojiNotAllowedMessage
              : duplicate
              ? 'មុខចំណាយនេះមានរួចហើយ'
              : null,
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('បោះបង់'),
        ),
        FilledButton(
          key: const Key('saveCategoryRename'),
          onPressed: canSave ? () => Navigator.pop(context, clean) : null,
          child: const Text('រក្សាទុក'),
        ),
      ],
    );
  }
}
