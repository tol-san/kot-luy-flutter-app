import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import 'package:kot_luy/data/expense_repository.dart';
import 'package:kot_luy/formatters/khmer_number_words.dart';
import 'package:kot_luy/models/expense.dart';
import 'package:kot_luy/screens/detail_screen.dart';
import 'package:kot_luy/screens/drive_backup_sheet.dart';
import 'package:kot_luy/screens/expense_form.dart';
import 'package:kot_luy/screens/pdf_export_sheet.dart';
import 'package:kot_luy/theme.dart';
import 'package:kot_luy/widgets/expense_chart.dart';
import 'package:kot_luy/widgets/home/home_app_bar.dart';
import 'package:kot_luy/widgets/home/home_report_section.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, required this.repository});
  final ExpenseRepository repository;
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  List<Expense> _expenses = [];
  List<ExpenseCategory> _categories = ExpenseCategory.values;
  ExpensePeriod _period = ExpensePeriod.month;
  ExpenseCategory? _category;
  String _query = '';
  bool _loading = true;
  bool _error = false;
  bool _reports = false;
  bool _search = false;
  bool _isSelecting = false;
  final Set<int> _selectedIds = {};
  bool _expandedCategoryLegend = false;
  final _searchController = TextEditingController();
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _load();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _searchController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _load();
  }

  Future<void> _load() async {
    try {
      final categories = await widget.repository.getCategories(
        includeArchived: true,
      );
      final expenses = await widget.repository.all(categories: categories);
      if (mounted) {
        setState(() {
          _expenses = expenses;
          _categories = categories;
          _loading = false;
          _error = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _error = true;
          _loading = false;
        });
      }
    }
  }

  List<Expense> get _inPeriod =>
      _expenses.where((e) => _period.contains(e.date, clock.now())).toList();

  List<Expense> get _filteredExpenses => _inPeriod
      .where(
        (e) =>
            (_category == null || e.category == _category) &&
            (_query.isEmpty ||
                e.title.toLowerCase().contains(_query) ||
                e.note.toLowerCase().contains(_query)),
      )
      .toList();

  Future<void> _showCategoryFilter() async {
    final selected = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      backgroundColor: paper,
      constraints: const BoxConstraints(maxWidth: 560),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (sheetContext) => SafeArea(
        top: false,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(sheetContext).height * 0.7,
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
                        'ច្រោះតាមមុខចំណាយ',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: ink,
                        ),
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
                child: ListView.builder(
                  key: const Key('categoryFilterList'),
                  shrinkWrap: true,
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                  itemCount: _categories.length + 1,
                  itemBuilder: (_, index) {
                    final category = index == 0 ? null : _categories[index - 1];
                    final isSelected = category == _category;
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      // Keep tile ink inside the scrolling viewport instead of
                      // painting it on the bottom sheet's shared Material.
                      child: Material(
                        type: MaterialType.transparency,
                        child: ListTile(
                          key: Key(
                            'filter_category_${category?.name ?? 'all'}',
                          ),
                          selected: isSelected,
                          selectedColor: green,
                          selectedTileColor:
                              category?.background ?? const Color(0xFFF0F2EB),
                          tileColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          leading: Icon(
                            category == null
                                ? Icons.apps_rounded
                                : Icons.circle,
                            color: category?.color ?? green,
                            size: category == null ? 22 : 12,
                          ),
                          title: Text(category?.label ?? 'មុខចំណាយទាំងអស់'),
                          trailing: isSelected
                              ? const Icon(Icons.check_rounded, color: green)
                              : null,
                          onTap: () => Navigator.pop(
                            sheetContext,
                            category?.name ?? 'all',
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
    if (!mounted || selected == null) return;
    setState(() {
      _category = selected == 'all'
          ? null
          : _categories.firstWhere((category) => category.name == selected);
    });
  }

  Future<void> _add() async {
    setState(() {
      _isSelecting = false;
      _selectedIds.clear();
    });
    await showExpenseForm(context, widget.repository);
    if (mounted) {
      await _load();
    }
  }

  Future<void> _confirmDeleteSelected() async {
    final count = _selectedIds.length;
    if (count == 0) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('លុបចំណាយដែលបានជ្រើសរើស?'),
        content: Text(
          'តើអ្នកប្រាកដជាចង់លុបចំណាយចំនួន $count នេះមែនទេ? សកម្មភាពនេះមិនអាចត្រឡប់ក្រោយបានទេ។',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('ទុកវិញ'),
          ),
          TextButton(
            key: const Key('confirmBulkDeleteButton'),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              'លុប ($count)',
              style: const TextStyle(color: Color(0xFFAD5347)),
            ),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      final idsToDelete = _selectedIds.toList();
      await widget.repository.deleteMultiple(idsToDelete);
      if (mounted) {
        setState(() {
          _selectedIds.clear();
          _isSelecting = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('បានលុបចំណាយចំនួន $count រួចរាល់'),
            behavior: SnackBarBehavior.floating,
          ),
        );
        await _load();
      }
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_isSelecting,
    onPopInvokedWithResult: (didPop, _) {
      if (!didPop && _isSelecting) {
        setState(() {
          _isSelecting = false;
          _selectedIds.clear();
        });
      }
    },
    child: Scaffold(
      body: SafeArea(
        bottom: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: RefreshIndicator(
              onRefresh: _load,
              child: CustomScrollView(
                slivers: [
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          HomeAppBar(
                            onPdfExport: () => PdfExportSheet.show(
                              context,
                              repository: widget.repository,
                            ),
                            onDriveBackup: () => DriveBackupSheet.show(
                              context,
                              widget.repository,
                              onDataRestored: _load,
                            ),
                          ),
                          const SizedBox(height: 18),
                          Text(
                            _reports
                                ? 'របាយការណ៍ចំណាយ'
                                : 'ចំណាយតូចៗ ក្ដីសុខធំៗ',
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w700,
                              letterSpacing: -.5,
                            ),
                          ),
                          const SizedBox(height: 5),
                          Text(
                            _reports
                                ? 'ស្វែងយល់ពីចំណាយរបស់អ្នក បន្តិចម្ដងៗ។'
                                : 'មើលថែចំណាយ ដូចមើលថែខ្លួនឯង។',
                            style: const TextStyle(color: muted, fontSize: 12),
                          ),
                          const SizedBox(height: 15),
                          _periodPicker(),
                          const SizedBox(height: 16),
                          _summary(),
                          const SizedBox(height: 14),
                          if (!_reports)
                            HomeCompanion(hasExpenses: _expenses.isNotEmpty),
                          const SizedBox(height: 15),
                          const Divider(height: 1),
                          const SizedBox(height: 15),
                          if (_reports)
                            HomeReportSection(
                              expenses: _inPeriod,
                              categories: _categories,
                              onPdfExport: () => PdfExportSheet.show(
                                context,
                                repository: widget.repository,
                              ),
                              companion: HomeCompanion(
                                hasExpenses: _expenses.isNotEmpty,
                              ),
                            )
                          else ...[
                            if (_isSelecting)
                              Row(
                                children: [
                                  IconButton(
                                    key: const Key('cancelSelectionButton'),
                                    tooltip: 'បោះបង់',
                                    onPressed: () => setState(() {
                                      _isSelecting = false;
                                      _selectedIds.clear();
                                    }),
                                    icon: const Icon(
                                      Icons.close_rounded,
                                      color: ink,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  Expanded(
                                    child: Text(
                                      _selectedIds.isEmpty
                                          ? 'ជ្រើសរើសចំណាយ'
                                          : 'បានជ្រើសរើស ${_selectedIds.length}',
                                      style: const TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.w700,
                                        color: ink,
                                      ),
                                    ),
                                  ),
                                  IconButton(
                                    key: const Key('selectAllButton'),
                                    tooltip:
                                        _selectedIds.length ==
                                                _filteredExpenses.length &&
                                            _filteredExpenses.isNotEmpty
                                        ? 'ដោះជម្រើសទាំងអស់'
                                        : 'ជ្រើសរើសទាំងអស់',
                                    icon: Icon(
                                      _selectedIds.length ==
                                                  _filteredExpenses.length &&
                                              _filteredExpenses.isNotEmpty
                                          ? Icons.deselect_rounded
                                          : Icons.select_all_rounded,
                                      color: ink,
                                      size: 22,
                                    ),
                                    onPressed: () {
                                      setState(() {
                                        final currentFilteredIds =
                                            _filteredExpenses
                                                .map((e) => e.id)
                                                .whereType<int>()
                                                .toSet();
                                        if (_selectedIds.containsAll(
                                          currentFilteredIds,
                                        )) {
                                          _selectedIds.removeAll(
                                            currentFilteredIds,
                                          );
                                        } else {
                                          _selectedIds.addAll(
                                            currentFilteredIds,
                                          );
                                        }
                                      });
                                    },
                                  ),
                                  IconButton(
                                    key: const Key(
                                      'deleteSelectedExpensesButton',
                                    ),
                                    tooltip: 'លុប',
                                    icon: Icon(
                                      Icons.delete_outline_rounded,
                                      color: _selectedIds.isEmpty
                                          ? muted
                                          : const Color(0xFFAD5347),
                                      size: 22,
                                    ),
                                    onPressed: _selectedIds.isEmpty
                                        ? null
                                        : _confirmDeleteSelected,
                                  ),
                                ],
                              )
                            else
                              Row(
                                children: [
                                  const Expanded(
                                    child: Text(
                                      'បញ្ជីចំណាយ',
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                  IconButton(
                                    key: const Key('enterSelectionModeButton'),
                                    tooltip: 'ជ្រើសរើសច្រើន',
                                    onPressed: _filteredExpenses.isEmpty
                                        ? null
                                        : () => setState(
                                            () => _isSelecting = true,
                                          ),
                                    icon: const Icon(
                                      Icons.checklist_rounded,
                                      color: ink,
                                      size: 22,
                                    ),
                                  ),
                                  IconButton(
                                    tooltip: 'ស្វែងរកចំណាយ',
                                    onPressed: () => setState(() {
                                      _search = !_search;
                                      if (!_search) {
                                        _query = '';
                                        _searchController.clear();
                                      }
                                    }),
                                    icon: Icon(
                                      _search
                                          ? Icons.search_off
                                          : Icons.search_rounded,
                                      color: ink,
                                      size: 23,
                                    ),
                                  ),
                                  IconButton(
                                    key: const Key('categoryFilterButton'),
                                    tooltip: 'ច្រោះតាមមុខចំណាយ',
                                    onPressed: _showCategoryFilter,
                                    icon: Icon(
                                      Icons.tune_rounded,
                                      color: _category == null ? muted : green,
                                      size: 22,
                                    ),
                                  ),
                                ],
                              ),
                            if (_search)
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                ),
                                child: TextField(
                                  controller: _searchController,
                                  decoration: const InputDecoration(
                                    hintText: 'ស្វែងរកឈ្មោះ ឬកំណត់ចំណាំ',
                                    prefixIcon: Icon(Icons.search),
                                  ),
                                  onChanged: (value) => setState(
                                    () => _query = value.trim().toLowerCase(),
                                  ),
                                ),
                              ),
                            if (_category != null)
                              InputChip(
                                label: Text(_category!.label),
                                onDeleted: () =>
                                    setState(() => _category = null),
                              ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  if (_loading)
                    const SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsets.all(40),
                        child: Center(child: CircularProgressIndicator()),
                      ),
                    )
                  else if (_error)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          children: [
                            const Text('មិនអាចអានទិន្នន័យបាន'),
                            TextButton(
                              onPressed: _load,
                              child: const Text('ព្យាយាមម្ដងទៀត'),
                            ),
                          ],
                        ),
                      ),
                    )
                  else if (!_reports)
                    _transactionList(),
                  const SliverToBoxAdapter(child: SizedBox(height: 30)),
                ],
              ),
            ),
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Container(
          decoration: const BoxDecoration(
            color: paper,
            border: Border(top: BorderSide(color: line)),
          ),
          child: Center(
            heightFactor: 1,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 640),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 12, 24, 14),
                child: Row(
                  children: [
                    HomeNavigationItem(
                      icon: Icons.space_dashboard_outlined,
                      label: 'ទិដ្ឋភាពទូទៅ',
                      selected: !_reports,
                      onTap: () => setState(() {
                        _reports = false;
                        _isSelecting = false;
                        _selectedIds.clear();
                      }),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: FilledButton.icon(
                        key: const Key('addExpense'),
                        onPressed: _add,
                        icon: SvgPicture.asset(
                          'assets/illustrations/wallet_arrow_up.svg',
                          width: 20,
                          height: 20,
                          colorFilter: const ColorFilter.mode(
                            Colors.white,
                            BlendMode.srcIn,
                          ),
                        ),
                        label: const Text('កត់ចំណាយ'),
                      ),
                    ),
                    const SizedBox(width: 16),
                    HomeNavigationItem(
                      icon: Icons.donut_small_outlined,
                      label: 'របាយការណ៍',
                      selected: _reports,
                      onTap: () => setState(() {
                        _reports = true;
                        _isSelecting = false;
                        _selectedIds.clear();
                      }),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );

  Widget _periodPicker() => Container(
    padding: const EdgeInsets.all(3),
    decoration: BoxDecoration(
      color: const Color(0xFFEDF1E3),
      borderRadius: BorderRadius.circular(28),
    ),
    child: Stack(
      children: [
        Positioned.fill(
          child: IgnorePointer(
            child: AnimatedAlign(
              key: const Key('periodPickerIndicator'),
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOutCubic,
              alignment: Alignment(
                -1 +
                    (2 *
                        ExpensePeriod.values.indexOf(_period) /
                        (ExpensePeriod.values.length - 1)),
                0,
              ),
              child: FractionallySizedBox(
                widthFactor: 1 / ExpensePeriod.values.length,
                heightFactor: 1,
                child: DecoratedBox(
                  key: const Key('periodPickerThumb'),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                  ),
                ),
              ),
            ),
          ),
        ),
        Row(
          children: ExpensePeriod.values
              .map(
                (p) => Expanded(
                  child: Semantics(
                    selected: p == _period,
                    child: Material(
                      color: Colors.transparent,
                      borderRadius: BorderRadius.circular(24),
                      child: InkWell(
                        key: Key('period_${p.name}'),
                        borderRadius: BorderRadius.circular(24),
                        onTap: p == _period
                            ? null
                            : () => setState(() {
                                _period = p;
                                _isSelecting = false;
                                _selectedIds.clear();
                              }),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Text(
                            p.label,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 12,
                              height: 1.5,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF145B32),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              )
              .toList(),
        ),
      ],
    ),
  );
  Widget _summary() {
    final expenses = _inPeriod;
    final total = expenses.fold(0, (a, e) => a + e.amount);
    final presentCategories = <String, ExpenseCategory>{
      for (final e in expenses) e.category.name: e.category,
    };
    final categories = _categories
        .where((c) => presentCategories.containsKey(c.name))
        .toList();
    for (final c in presentCategories.values) {
      if (!categories.any((x) => x.name == c.name)) {
        categories.add(c);
      }
    }
    return Container(
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: line),
        borderRadius: BorderRadius.circular(25),
      ),
      child: Column(
        children: [
          Row(
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
                    const SizedBox(height: 2),
                    Text(
                      khmerRielWords(total),
                      key: const Key('totalAmountWords'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: muted, fontSize: 11),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      '${expenses.length} កំណត់ត្រា • ${_period.label}',
                      style: const TextStyle(fontSize: 10, color: muted),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              InkWell(
                borderRadius: BorderRadius.circular(80),
                onTap: () => setState(() => _reports = true),
                child: ExpenseChart(
                  expenses: expenses,
                  size: MediaQuery.sizeOf(context).width < 370 ? 94 : 112,
                ),
              ),
            ],
          ),
          if (categories.isNotEmpty) ...[
            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 14),
            _buildCategoryLegend(categories),
          ],
        ],
      ),
    );
  }

  Widget _buildCategoryLegend(List<ExpenseCategory> categories) {
    Widget legendItem(ExpenseCategory c) => Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(color: c.color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 5),
        Text(c.label, style: const TextStyle(fontSize: 10, color: muted)),
      ],
    );

    if (_expandedCategoryLegend) {
      return Wrap(
        spacing: 16,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          ...categories.map(legendItem),
          InkWell(
            key: const Key('collapseCategoriesButton'),
            borderRadius: BorderRadius.circular(6),
            onTap: () => setState(() => _expandedCategoryLegend = false),
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 2, vertical: 1),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'បង្រួម',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: green,
                    ),
                  ),
                  SizedBox(width: 2),
                  Icon(Icons.expand_less_rounded, size: 13, color: green),
                ],
              ),
            ),
          ),
        ],
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final totalWidth = constraints.maxWidth;
        const spacing = 16.0;

        double measureWidth(String text) {
          final tp = TextPainter(
            text: TextSpan(text: text, style: const TextStyle(fontSize: 10)),
            textDirection: TextDirection.ltr,
            maxLines: 1,
          )..layout();
          return 11.0 + tp.width;
        }

        double measureTextOnly(String text) {
          final tp = TextPainter(
            text: TextSpan(
              text: text,
              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600),
            ),
            textDirection: TextDirection.ltr,
            maxLines: 1,
          )..layout();
          return tp.width + 4.0;
        }

        final row1 = <ExpenseCategory>[];
        final row2 = <ExpenseCategory>[];
        int i = 0;
        double r1Width = 0;

        while (i < categories.length) {
          final w = measureWidth(categories[i].label);
          final needed = row1.isEmpty ? w : (w + spacing);
          if (r1Width + needed <= totalWidth - 4) {
            row1.add(categories[i]);
            r1Width += needed;
            i++;
          } else {
            break;
          }
        }

        double remWidth = 0;
        bool allRemainingFit = true;
        for (int j = i; j < categories.length; j++) {
          final w = measureWidth(categories[j].label);
          final needed = (j == i) ? w : (w + spacing);
          if (remWidth + needed <= totalWidth - 4) {
            remWidth += needed;
          } else {
            allRemainingFit = false;
            break;
          }
        }

        if (allRemainingFit) {
          while (i < categories.length) {
            row2.add(categories[i]);
            i++;
          }
        } else {
          final moreReserve = measureTextOnly('+99 ទៀត') + spacing;
          double r2Width = 0;
          while (i < categories.length) {
            final w = measureWidth(categories[i].label);
            final needed = row2.isEmpty ? w : (w + spacing);
            if (r2Width + needed + moreReserve <= totalWidth - 4) {
              row2.add(categories[i]);
              r2Width += needed;
              i++;
            } else {
              break;
            }
          }
        }

        final remainingCount = categories.length - (row1.length + row2.length);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Wrap(spacing: spacing, children: row1.map(legendItem).toList()),
            if (row2.isNotEmpty || remainingCount > 0) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: spacing,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  ...row2.map(legendItem),
                  if (remainingCount > 0)
                    InkWell(
                      key: const Key('expandCategoriesButton'),
                      borderRadius: BorderRadius.circular(6),
                      onTap: () =>
                          setState(() => _expandedCategoryLegend = true),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 2,
                          vertical: 1,
                        ),
                        child: Text(
                          '+$remainingCount ទៀត',
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: green,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ],
        );
      },
    );
  }

  Widget _transactionList() {
    final items = _filteredExpenses;
    if (items.isEmpty) {
      return SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 22, 24, 16),
          child: Column(
            children: [
              Icon(
                _query.isNotEmpty || _category != null
                    ? Icons.search_off_rounded
                    : Icons.receipt_long_outlined,
                color: const Color(0xFFA8B29B),
                size: 36,
              ),
              const SizedBox(height: 10),
              Text(
                _expenses.isEmpty
                    ? 'ចាប់ផ្ដើមទំព័រថ្មីរបស់អ្នក'
                    : 'មិនមានចំណាយក្នុងជម្រើសនេះ',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 5),
              Text(
                _expenses.isEmpty
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
          final isSelected = e.id != null && _selectedIds.contains(e.id);
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
                      if (e.id != null) {
                        setState(() {
                          _isSelecting = true;
                          _selectedIds.add(e.id!);
                        });
                      }
                    },
                    onTap: () async {
                      if (_isSelecting) {
                        if (e.id != null) {
                          setState(() {
                            if (_selectedIds.contains(e.id)) {
                              _selectedIds.remove(e.id);
                            } else {
                              _selectedIds.add(e.id!);
                            }
                          });
                        }
                        return;
                      }
                      await Navigator.push(
                        context,
                        MaterialPageRoute<void>(
                          builder: (_) => DetailScreen(
                            expense: e,
                            repository: widget.repository,
                          ),
                        ),
                      );
                      if (mounted) _load();
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        vertical: 14,
                        horizontal: 8,
                      ),
                      child: Row(
                        children: [
                          if (_isSelecting) ...[
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
                                  e.title,
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
                          if (!_isSelecting) ...[
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
