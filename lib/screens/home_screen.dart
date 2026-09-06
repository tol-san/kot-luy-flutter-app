import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../data/expense_repository.dart';
import '../models/expense.dart';
import '../theme.dart';
import '../widgets/expense_chart.dart';
import 'detail_screen.dart';
import 'drive_backup_sheet.dart';
import 'expense_form.dart';
import 'pdf_export_sheet.dart';

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
      final expenses = await widget.repository.all();
      final categories = await widget.repository.getCategories();
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
                        _header(),
                        const SizedBox(height: 18),
                        Text(
                          _reports ? 'របាយការណ៍ចំណាយ' : 'ចំណាយតូចៗ ក្ដីសុខធំៗ',
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
                        if (!_reports) _companion(),
                        const SizedBox(height: 15),
                        const Divider(height: 1),
                        const SizedBox(height: 15),
                        if (_reports)
                          ..._reportWidgets()
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
                                  tooltip: _selectedIds.length ==
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
                                        _selectedIds.addAll(currentFilteredIds);
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
                                PopupMenuButton<String>(
                                  tooltip: 'ច្រោះតាមមុខចំណាយ',
                                  icon: Icon(
                                    Icons.tune_rounded,
                                    color: _category == null ? muted : green,
                                    size: 22,
                                  ),
                                  onSelected: (value) => setState(
                                    () => _category = value == 'all'
                                        ? null
                                        : _categories.firstWhere(
                                            (c) => c.name == value,
                                            orElse: () =>
                                                ExpenseCategory.fromName(
                                                  value,
                                                  _categories,
                                                ),
                                          ),
                                  ),
                                  itemBuilder: (_) => [
                                    const PopupMenuItem(
                                      value: 'all',
                                      child: Text('មុខចំណាយទាំងអស់'),
                                    ),
                                    ..._categories.map(
                                      (c) => PopupMenuItem(
                                        value: c.name,
                                        child: Text(c.label),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          if (_search)
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 12),
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
                              onDeleted: () => setState(() => _category = null),
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
                  _nav(
                    Icons.space_dashboard_outlined,
                    'ទិដ្ឋភាពទូទៅ',
                    !_reports,
                    () => setState(() {
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
                  _nav(
                    Icons.donut_small_outlined,
                    'របាយការណ៍',
                    _reports,
                    () => setState(() {
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

  Widget _header() => Row(
    children: [
      Image.asset(
        'assets/logo.png',
        width: 93,
        height: 36,
        fit: BoxFit.contain,
        semanticLabel: 'កត់លុយ',
      ),
      const Spacer(),
      IconButton(
        key: const Key('pdfExportHeaderButton'),
        tooltip: 'ទាញយករបាយការណ៍ PDF',
        onPressed: () => PdfExportSheet.show(
          context,
          repository: widget.repository,
        ),
        icon: Container(
          padding: const EdgeInsets.all(7),
          decoration: BoxDecoration(
            color: const Color(0xFFEDF1E3),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(
            Icons.picture_as_pdf_outlined,
            color: green,
            size: 20,
          ),
        ),
      ),
      const SizedBox(width: 6),
      IconButton(
        tooltip: 'បម្រុងទុកទិន្នន័យ (Google Drive)',
        onPressed: () => DriveBackupSheet.show(
          context,
          widget.repository,
          onDataRestored: _load,
        ),
        icon: Container(
          padding: const EdgeInsets.all(7),
          decoration: BoxDecoration(
            color: const Color(0xFFEDF1E3),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(
            Icons.cloud_sync_outlined,
            color: green,
            size: 20,
          ),
        ),
      ),
    ],
  );
  Widget _periodPicker() => Container(
    padding: const EdgeInsets.all(3),
    decoration: BoxDecoration(
      color: const Color(0xFFEDF1E3),
      borderRadius: BorderRadius.circular(28),
    ),
    child: Row(
      children: ExpensePeriod.values
          .map(
            (p) => Expanded(
              child: Semantics(
                selected: p == _period,
                child: Material(
                  color: _period == p ? Colors.white : Colors.transparent,
                  borderRadius: BorderRadius.circular(24),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(24),
                    onTap: () => setState(() {
                      _period = p;
                      _isSelecting = false;
                      _selectedIds.clear();
                    }),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Text(
                        p.label,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 12,
                          height: 1.5,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF145B32),
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
  );
  Widget _summary() {
    final expenses = _inPeriod;
    final total = expenses.fold(0, (a, e) => a + e.amount);
    final presentCategories = <String, ExpenseCategory>{
      for (final e in expenses) e.category.name: e.category,
    };
    final categories = _categories.where((c) => presentCategories.containsKey(c.name)).toList();
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
                    const SizedBox(height: 10),
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
          decoration: BoxDecoration(
            color: c.color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 5),
        Text(
          c.label,
          style: const TextStyle(fontSize: 10, color: muted),
        ),
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
                  Icon(
                    Icons.expand_less_rounded,
                    size: 13,
                    color: green,
                  ),
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
            text: TextSpan(
              text: text,
              style: const TextStyle(fontSize: 10),
            ),
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
            Wrap(
              spacing: spacing,
              children: row1.map(legendItem).toList(),
            ),
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

  Widget _companion() => Container(
    padding: const EdgeInsets.fromLTRB(18, 8, 6, 8),
    decoration: BoxDecoration(
      color: const Color(0xFFEDF1E3),
      borderRadius: BorderRadius.circular(22),
    ),
    child: Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'ហេ៎! ធ្វើបានល្អហើយ 🌿',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 5),
              Text(
                _expenses.isEmpty
                    ? 'ចាប់ផ្ដើមពីចំណាយដំបូង\nខ្ញុំនៅទីនេះ ជួយអ្នកកត់ត្រា។'
                    : 'រាល់ការកត់ត្រា ជួយឱ្យអ្នក\nស្គាល់ទម្លាប់ចំណាយខ្លួនឯង។',
                style: const TextStyle(
                  color: Color(0xFF505F46),
                  fontSize: 11,
                  height: 1.8,
                ),
              ),
            ],
          ),
        ),
        SvgPicture.asset(
          'assets/illustrations/wallet.svg',
          width: 96,
          height: 90,
          semanticsLabel: 'មិត្តកាបូបលុយញញឹម',
        ),
      ],
    ),
  );

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

  List<Widget> _reportWidgets() {
    final expenses = _inPeriod;
    final total = expenses.fold(0, (a, e) => a + e.amount);
    final presentMap = <String, ExpenseCategory>{
      for (final c in _categories) c.name: c,
      for (final e in expenses) e.category.name: e.category,
    };
    final totals = {
      for (final c in presentMap.values)
        c: expenses
            .where((e) => e.category.name == c.name)
            .fold(0, (a, e) => a + e.amount),
    };
    final sorted = totals.entries.where((e) => e.value > 0).toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return [
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text(
            'ចំណាយតាមមុខចំណាយ',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          ),
          FilledButton.tonalIcon(
            key: const ValueKey('pdfExportReportButton'),
            style: FilledButton.styleFrom(
              visualDensity: VisualDensity.compact,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            ),
            icon: const Icon(Icons.picture_as_pdf_rounded, size: 16),
            label: const Text('ទាញយក PDF', style: TextStyle(fontSize: 12)),
            onPressed: () => PdfExportSheet.show(
              context,
              repository: widget.repository,
            ),
          ),
        ],
      ),
      const SizedBox(height: 8),
      if (total == 0)
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 40),
          child: Center(
            child: Text(
              'កត់ចំណាយដំបូង ដើម្បីមើលរបាយការណ៍។',
              style: TextStyle(color: muted, fontSize: 12),
            ),
          ),
        ),
      ...sorted.map(
        (entry) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 14),
          child: Column(
            children: [
              Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: entry.key.color,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      entry.key.label,
                      style: const TextStyle(fontSize: 13),
                    ),
                  ),
                  Text(
                    riel(entry.value),
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    '${(entry.value / total * 100).toStringAsFixed(1)}%',
                    style: const TextStyle(color: muted, fontSize: 11),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(5),
                child: LinearProgressIndicator(
                  value: entry.value / total,
                  backgroundColor: entry.key.background,
                  color: entry.key.color,
                  minHeight: 7,
                ),
              ),
            ],
          ),
        ),
      ),
      const SizedBox(height: 24),
      _companion(),
    ];
  }

  Widget _nav(IconData icon, String label, bool selected, VoidCallback onTap) =>
      InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 5, horizontal: 2),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: selected ? green : muted, size: 22),
              const SizedBox(height: 5),
              Text(
                label,
                style: TextStyle(
                  fontSize: 9,
                  color: selected ? green : muted,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
                ),
              ),
            ],
          ),
        ),
      );
}
