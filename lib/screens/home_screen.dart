import 'dart:async';

import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:vector_graphics/vector_graphics.dart';

import 'package:kot_luy/data/expense_repository.dart';
import 'package:kot_luy/models/expense.dart';
import 'package:kot_luy/screens/drive_backup_sheet.dart';
import 'package:kot_luy/screens/expense_form.dart';
import 'package:kot_luy/screens/pdf_export_sheet.dart';
import 'package:kot_luy/screens/reminder_settings_sheet.dart';
import 'package:kot_luy/services/reminder_service.dart';
import 'package:kot_luy/theme.dart';
import 'package:kot_luy/widgets/home/home_app_bar.dart';
import 'package:kot_luy/widgets/home/home_expense_list.dart';
import 'package:kot_luy/widgets/home/home_list_header.dart';
import 'package:kot_luy/widgets/home/home_period_picker.dart';
import 'package:kot_luy/widgets/home/home_report_section.dart';
import 'package:kot_luy/widgets/home/home_selection_bar.dart';
import 'package:kot_luy/widgets/home/home_summary_card.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    required this.repository,
    this.reminderService,
    this.initialExpenses,
    this.initialCategories,
    this.initialHasAnyExpenses,
  });
  final ExpenseRepository repository;
  final ReminderService? reminderService;
  final List<Expense>? initialExpenses;
  final List<ExpenseCategory>? initialCategories;
  final bool? initialHasAnyExpenses;
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  late List<Expense> _expenses = widget.initialExpenses ?? [];
  late List<ExpenseCategory> _categories =
      widget.initialCategories ?? ExpenseCategory.values;
  ExpensePeriod _period = ExpensePeriod.month;
  ReminderKind? _summaryReminder;
  ExpenseCategory? _category;
  String _query = '';
  late bool _loading = widget.initialExpenses == null;
  bool _error = false;
  bool _reports = false;
  bool _search = false;
  bool _isSelecting = false;
  bool _isDeleting = false;
  late bool _hasAnyExpenses = widget.initialHasAnyExpenses ?? false;
  int _loadRequest = 0;
  final Set<int> _selectedIds = {};
  final _searchController = TextEditingController();
  final _scrollController = ScrollController();
  bool _showScrollToTop = false;

  // ---- Cache: ការពារ loop ២ ដងរៀងរាល់ build() ----
  List<Expense> _cachedFiltered = [];
  Timer? _searchDebounce;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _rebuildFiltered();
    WidgetsBinding.instance.addObserver(this);
    widget.reminderService?.onOpenExpense = _add;
    widget.reminderService?.onOpenSummary = _openSummary;
    if (widget.reminderService?.takePendingOpenExpense() ?? false) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _add());
    }
    final pendingSummary = widget.reminderService?.takePendingSummary();
    if (pendingSummary != null) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _openSummary(pendingSummary),
      );
    }
    if (widget.initialExpenses == null) {
      _load();
    }
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final show = _scrollController.offset > 250;
    if (show != _showScrollToTop) {
      setState(() => _showScrollToTop = show);
    }
  }

  void _scrollToTop() {
    if (!_scrollController.hasClients) return;
    _scrollController.animateTo(
      0,
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    WidgetsBinding.instance.removeObserver(this);
    widget.reminderService?.onOpenExpense = null;
    widget.reminderService?.onOpenSummary = null;
    _searchDebounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _load();
  }

  Future<void> _load() async {
    final request = ++_loadRequest;
    try {
      final now = clock.now();
      final range = _dateRange(_period, now);
      final categories = await widget.repository.getCategories(
        includeArchived: true,
      );
      final results = await Future.wait<Object>([
        widget.repository.all(
          categories: categories,
          categoriesAreComplete: true,
          fromInclusive: range.start,
          toExclusive: range.end,
        ),
        widget.repository.hasAnyExpenses(),
      ]);
      if (request != _loadRequest) return;
      final expenses = results[0] as List<Expense>;
      final hasAnyExpenses = results[1] as bool;
      if (mounted) {
        setState(() {
          _expenses = expenses;
          _categories = categories;
          _hasAnyExpenses = hasAnyExpenses;
          _loading = false;
          _error = false;
          _rebuildFiltered(); // cache ជំនួស getter — loop ១ ដងប៉ុណ្ណោះ
        });
      }
    } catch (_) {
      if (request != _loadRequest) return;
      if (mounted) {
        setState(() {
          _error = true;
          _loading = false;
        });
      }
    }
  }

  ({DateTime? start, DateTime? end}) _dateRange(
    ExpensePeriod period,
    DateTime now,
  ) {
    final day = DateTime(now.year, now.month, now.day);
    if (_summaryReminder == ReminderKind.weekly) {
      final thisMonday = day.subtract(Duration(days: day.weekday - 1));
      return (
        start: thisMonday.subtract(const Duration(days: 7)),
        end: thisMonday,
      );
    }
    if (_summaryReminder == ReminderKind.monthly) {
      return (
        start: DateTime(now.year, now.month - 1),
        end: DateTime(now.year, now.month),
      );
    }
    return switch (period) {
      ExpensePeriod.today => (
        start: day,
        end: day.add(const Duration(days: 1)),
      ),
      ExpensePeriod.week => (
        start: day.subtract(Duration(days: day.weekday - 1)),
        end: day.add(Duration(days: 8 - day.weekday)),
      ),
      ExpensePeriod.month => (
        start: DateTime(now.year, now.month),
        end: DateTime(now.year, now.month + 1),
      ),
      ExpensePeriod.all => (start: null, end: null),
    };
  }

  void _openSummary(ReminderKind kind) {
    if (!mounted) return;
    final period = kind == ReminderKind.weekly
        ? ExpensePeriod.week
        : ExpensePeriod.month;
    setState(() {
      _reports = true;
      _period = period;
      _summaryReminder = kind;
      _loading = true;
      _isSelecting = false;
      _selectedIds.clear();
    });
    unawaited(_load());
  }

  void _selectPeriod(ExpensePeriod period) {
    setState(() {
      _period = period;
      _summaryReminder = null;
      _loading = true;
      _isSelecting = false;
      _selectedIds.clear();
    });
    unawaited(_load());
  }

  /// ======================================================
  /// Cache filter — ហៅ ១ ដងពេល data/period/category/query ផ្លាស់ប្ដូរ
  /// ជំនួស getter ២ ដែល loop រៀងរាល់ build()
  /// ======================================================
  void _rebuildFiltered() {
    final now = clock.now();
    final range = _dateRange(_period, now);
    _cachedFiltered = _expenses
        .where(
          (e) =>
              (range.start == null || !e.date.isBefore(range.start!)) &&
              (range.end == null || e.date.isBefore(range.end!)) &&
              (_category == null || e.category == _category) &&
              (_query.isEmpty ||
                  e.category.label.toLowerCase().contains(_query) ||
                  e.note.toLowerCase().contains(_query)),
        )
        .toList();
  }

  // Helper used by summary card and report section (needs unfiltered period data)
  List<Expense> get _inPeriod {
    final now = clock.now();
    final range = _dateRange(_period, now);
    return _expenses
        .where(
          (e) =>
              (range.start == null || !e.date.isBefore(range.start!)) &&
              (range.end == null || e.date.isBefore(range.end!)),
        )
        .toList();
  }

  List<Expense> get _filteredExpenses => _cachedFiltered;

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
      _rebuildFiltered(); // cache ចាំបាច់ refresh ពេល category ផ្លាស់ប្ដូរ
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
      setState(() => _isDeleting = true); // ✅ progress overlay
      try {
        await widget.repository.deleteMultiple(idsToDelete);
        if (mounted) {
          setState(() {
            _selectedIds.clear();
            _isSelecting = false;
            _isDeleting = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('បានលុបចំណាយចំនួន $count រួចរាល់'),
              behavior: SnackBarBehavior.floating,
            ),
          );
          await _load();
        }
      } catch (_) {
        if (mounted) setState(() => _isDeleting = false);
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
    child: Stack(
      children: [
        Scaffold(
          body: SafeArea(
            bottom: false,
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 640),
                child: RefreshIndicator(
                  onRefresh: _load,
                  child: CustomScrollView(
                    controller: _scrollController,
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
                                  onDataRestored: () async {
                                    widget.repository.invalidateCategoryCache();
                                    await _load();
                                  },
                                ),
                                onReminderSettings:
                                    widget.reminderService == null
                                    ? null
                                    : () => ReminderSettingsSheet.show(
                                        context,
                                        reminderService:
                                            widget.reminderService!,
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
                                style: const TextStyle(
                                  color: muted,
                                  fontSize: 12,
                                ),
                              ),
                              const SizedBox(height: 15),
                              HomePeriodPicker(
                                period: _period,
                                onSelect: _selectPeriod,
                              ),
                              if (_summaryReminder != null)
                                Align(
                                  alignment: Alignment.centerLeft,
                                  child: TextButton(
                                    key: const Key('currentPeriodButton'),
                                    onPressed: () => _selectPeriod(_period),
                                    child: Text(
                                      _summaryReminder == ReminderKind.weekly
                                          ? 'សប្ដាហ៍មុន • មើលសប្ដាហ៍នេះ'
                                          : 'ខែមុន • មើលខែនេះ',
                                    ),
                                  ),
                                ),
                              const SizedBox(height: 16),
                              HomeSummaryCard(
                                expenses: _inPeriod,
                                categories: _categories,
                                period: _period,
                                periodLabel:
                                    _summaryReminder == ReminderKind.weekly
                                    ? 'សប្ដាហ៍មុន'
                                    : _summaryReminder == ReminderKind.monthly
                                    ? 'ខែមុន'
                                    : null,
                                onOpenReports: () =>
                                    setState(() => _reports = true),
                              ),
                              const SizedBox(height: 14),
                              if (!_reports)
                                HomeCompanion(hasExpenses: _hasAnyExpenses),
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
                                    hasExpenses: _hasAnyExpenses,
                                  ),
                                )
                              else ...[
                                if (_isSelecting)
                                  HomeSelectionBar(
                                    selectedCount: _selectedIds.length,
                                    totalCount: _filteredExpenses.length,
                                    onCancel: () => setState(() {
                                      _isSelecting = false;
                                      _selectedIds.clear();
                                    }),
                                    onToggleAll: () {
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
                                    onDelete: _confirmDeleteSelected,
                                  )
                                else
                                  HomeListHeader(
                                    canEnterSelection:
                                        _filteredExpenses.isNotEmpty,
                                    isSearchActive: _search,
                                    isCategoryFiltered: _category != null,
                                    onEnterSelection: () =>
                                        setState(() => _isSelecting = true),
                                    onToggleSearch: () => setState(() {
                                      _search = !_search;
                                      if (!_search) {
                                        _searchDebounce?.cancel();
                                        _query = '';
                                        _searchController.clear();
                                        _rebuildFiltered();
                                      }
                                    }),
                                    onCategoryFilter: _showCategoryFilter,
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
                                      onChanged: (value) {
                                        // ✅ Debounce 300ms — filter runs ១ ដង ក្រោយ user ឈប់វាយ
                                        _searchDebounce?.cancel();
                                        _searchDebounce = Timer(
                                          const Duration(milliseconds: 300),
                                          () => setState(() {
                                            _query = value.trim().toLowerCase();
                                            _rebuildFiltered();
                                          }),
                                        );
                                      },
                                    ),
                                  ),
                                if (_category != null)
                                  InputChip(
                                    label: Text(_category!.label),
                                    onDeleted: () => setState(() {
                                      _category = null;
                                      _rebuildFiltered();
                                    }),
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
                        HomeExpenseList(
                          expenses: _filteredExpenses,
                          repository: widget.repository,
                          hasAnyExpenses: _hasAnyExpenses,
                          query: _query,
                          category: _category,
                          isSelecting: _isSelecting,
                          selectedIds: _selectedIds,
                          onToggleSelect: (id) => setState(() {
                            if (_selectedIds.contains(id)) {
                              _selectedIds.remove(id);
                            } else {
                              _selectedIds.add(id);
                            }
                          }),
                          onLongPress: (id) => setState(() {
                            _isSelecting = true;
                            _selectedIds.add(id);
                          }),
                          onLoaded: _load,
                        ),
                      const SliverToBoxAdapter(child: SizedBox(height: 80)),
                    ],
                  ),
                ),
              ),
            ),
          ),
          floatingActionButton: IgnorePointer(
            ignoring: !_showScrollToTop,
            child: AnimatedScale(
              scale: _showScrollToTop ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOutCubic,
              child: FloatingActionButton.small(
                key: const Key('scrollToTopButton'),
                heroTag: 'scrollToTop',
                onPressed: _scrollToTop,
                backgroundColor: Colors.white,
                foregroundColor: green,
                elevation: 3,
                highlightElevation: 5,
                shape: const CircleBorder(
                  side: BorderSide(color: line, width: 1),
                ),
                child: const Icon(
                  Icons.keyboard_arrow_up_rounded,
                  size: 26,
                  color: green,
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
                          onTap: () {
                            if (_summaryReminder != null) {
                              _selectPeriod(_period);
                            }
                            setState(() {
                              _reports = false;
                              _isSelecting = false;
                              _selectedIds.clear();
                            });
                          },
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: FilledButton.icon(
                            key: const Key('addExpense'),
                            onPressed: _add,
                            icon: SvgPicture(
                              const AssetBytesLoader(
                                'assets/illustrations/wallet_arrow_up.svg.vec',
                              ),
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
        ), // ← close Scaffold
        // ✅ Overlay ពេល delete ច្រើន — ការពារ double-tap
        if (_isDeleting)
          const Positioned.fill(
            child: AbsorbPointer(
              child: ColoredBox(
                color: Color(0x66000000),
                child: Center(
                  child: CircularProgressIndicator(color: Colors.white),
                ),
              ),
            ),
          ),
      ],
    ),
  );
}
