import 'dart:async';

import 'package:clock/clock.dart';
import 'package:flutter/material.dart';

import '../data/expense_repository.dart';
import '../models/expense.dart';
import '../theme.dart';
import '../widgets/riel_input_formatter.dart';
import 'category_management_sheet.dart';

Future<bool?> showExpenseForm(
  BuildContext context,
  ExpenseRepository repository, {
  Expense? expense,
}) => showModalBottomSheet<bool>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  backgroundColor: paper,
  showDragHandle: true,
  constraints: const BoxConstraints(maxWidth: 560),
  builder: (_) => ExpenseForm(repository: repository, expense: expense),
);

class ExpenseForm extends StatefulWidget {
  const ExpenseForm({super.key, required this.repository, this.expense});
  final ExpenseRepository repository;
  final Expense? expense;
  @override
  State<ExpenseForm> createState() => _ExpenseFormState();
}

class _ExpenseFormState extends State<ExpenseForm> {
  final _form = GlobalKey<FormState>();
  late final _amount = TextEditingController(
    text: formatRielInput(widget.expense?.amount.toString() ?? ''),
  );
  late ExpenseCategory _category =
      widget.expense?.category ?? ExpenseCategory.breakfast;
  List<ExpenseCategory> _categories = ExpenseCategory.values;
  late DateTime _date = widget.expense?.date ?? clock.now();
  late bool _isCustomDateTime = widget.expense != null;
  Timer? _ticker;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadCategories();
    if (!_isCustomDateTime) {
      _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
        if (!_isCustomDateTime && mounted) {
          final now = clock.now();
          if (_date.minute != now.minute ||
              _date.hour != now.hour ||
              _date.day != now.day) {
            setState(() => _date = now);
          }
        }
      });
    }
  }

  Future<void> _loadCategories() async {
    final list = await widget.repository.getCategories();
    if (mounted) {
      setState(() {
        _categories = list;
        if (widget.expense != null) {
          _category = list.firstWhere(
            (c) => c.name == widget.expense!.category.name,
            orElse: () => widget.expense!.category,
          );
        } else if (!_categories.any((c) => c == _category)) {
          _category = _categories.first;
        }
      });
    }
  }

  Future<void> _manageCategories() async {
    final updated = await CategoryManagementSheet.show(
      context,
      widget.repository,
    );
    if (!mounted) return;
    if (updated != null) {
      setState(() {
        _categories = updated;
        if (!_categories.any((c) => c == _category)) {
          _category = _categories.first;
        }
      });
    } else {
      await _loadCategories();
    }
  }

  Future<void> _showCategoryPickerSheet() async {
    final selected = await showModalBottomSheet<ExpenseCategory>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(ctx).height * 0.75,
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
                        'ជ្រើសរើសប្រភេទចំណាយ',
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
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                  itemCount: _categories.length,
                  itemBuilder: (ctx, index) {
                    final cat = _categories[index];
                    final isSel = cat == _category;
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Material(
                        color: isSel ? cat.background : Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                          side: BorderSide(
                            color: isSel ? cat.color : line,
                            width: isSel ? 1.5 : 1,
                          ),
                        ),
                        child: ListTile(
                        key: Key('picker_category_${cat.name}'),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        leading: Container(
                          width: 12,
                          height: 12,
                          decoration: BoxDecoration(
                            color: cat.color,
                            shape: BoxShape.circle,
                          ),
                        ),
                        title: Text(
                          cat.label,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: isSel ? FontWeight.w700 : FontWeight.w600,
                            color: isSel ? cat.color : ink,
                          ),
                        ),
                        trailing: isSel
                            ? Icon(Icons.check_circle_rounded, color: cat.color, size: 20)
                            : null,
                        onTap: () => Navigator.pop(ctx, cat),
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
                    'រៀបចំ ឬ បន្ថែមប្រភេទថ្មី',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: green,
                    ),
                  ),
                  onPressed: () async {
                    Navigator.pop(ctx);
                    await _manageCategories();
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
    if (selected != null && mounted) {
      setState(() => _category = selected);
    }
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _amount.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving || !_form.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final title = _category.label;
      final now = clock.now();
      var dateToSave = _isCustomDateTime ? _date : now;
      if (dateToSave.isAfter(now)) {
        dateToSave = now;
      }
      await widget.repository.save(
        Expense(
          id: widget.expense?.id,
          title: title,
          amount: parseRielInput(_amount.text),
          category: _category,
          date: dateToSave,
          note: '',
        ),
      );
      if (mounted) Navigator.pop(context, true);
    } catch (_) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = 'រក្សាទុកមិនបាន សូមព្យាយាមម្ដងទៀត';
        });
      }
    }
  }

  Future<void> _pickDate() async {
    final now = clock.now();
    final initial = _date.isAfter(now) ? now : _date;
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2000),
      lastDate: now,
    );
    if (picked != null && mounted) {
      _ticker?.cancel();
      final newDate = DateTime(
        picked.year,
        picked.month,
        picked.day,
        _date.hour,
        _date.minute,
      );
      setState(() {
        _isCustomDateTime = true;
        _date = newDate.isAfter(now) ? now : newDate;
      });
    }
  }

  Future<void> _pickTime() async {
    final pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(
        hour: _date.hour,
        minute: _date.minute,
      ),
    );
    if (pickedTime != null && mounted) {
      _ticker?.cancel();
      final now = clock.now();
      final candidate = DateTime(
        _date.year,
        _date.month,
        _date.day,
        pickedTime.hour,
        pickedTime.minute,
      );
      if (candidate.isAfter(now)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('មិនអាចកំណត់ម៉ោងលើសពីពេលបច្ចុប្បន្នបានទេ'),
          ),
        );
        setState(() {
          _isCustomDateTime = true;
          _date = now;
        });
      } else {
        setState(() {
          _isCustomDateTime = true;
          _date = candidate;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_saving,
    child: Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
        child: SafeArea(
          top: false,
          child: Form(
            key: _form,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        widget.expense == null ? 'កត់ចំណាយថ្មី' : 'កែប្រែចំណាយ',
                        style: const TextStyle(
                          fontSize: 23,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: 'បិទ',
                      onPressed: _saving ? null : () => Navigator.pop(context),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
                const Text(
                  'កត់បន្តិចម្ដងៗ ស្គាល់ចំណាយកាន់តែច្បាស់ 🌱',
                  style: TextStyle(color: muted, fontSize: 12),
                ),
                const SizedBox(height: 23),
                const Text(
                  'ចំនួនទឹកប្រាក់',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  key: const Key('amountInput'),
                  controller: _amount,
                  keyboardType: TextInputType.number,
                  inputFormatters: [RielInputFormatter()],
                  autovalidateMode: AutovalidateMode.onUserInteraction,
                  onChanged: (_) => _form.currentState?.validate(),
                  style: const TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.w700,
                    color: ink,
                  ),
                  decoration: const InputDecoration(
                    hintText: '0',
                    suffixIcon: Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '៛ រៀល',
                            style: TextStyle(color: green, fontSize: 15),
                          ),
                        ],
                      ),
                    ),
                  ),
                  validator: (value) =>
                      parseRielInput(value) <= 0
                          ? 'សូមបញ្ចូលចំនួនប្រាក់លើសពី 0'
                          : null,
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    ...[5000, 10000, 20000, 50000, 100000].map(
                      (v) => ActionChip(
                        key: Key('quick_amount_$v'),
                        label: Text(
                          '+${riel(v)}',
                          style: const TextStyle(fontSize: 11),
                        ),
                        side: const BorderSide(color: line),
                        onPressed: () {
                          final current = parseRielInput(_amount.text);
                          final next = current + v;
                          if (next <= 999999999999) {
                            final text = formatRielInput('$next');
                            _amount.value = TextEditingValue(
                              text: text,
                              selection: TextSelection.collapsed(
                                offset: text.length,
                              ),
                            );
                            _form.currentState?.validate();
                          }
                        },
                      ),
                    ),
                    ActionChip(
                      key: const Key('clearAmount'),
                      avatar: const Icon(
                        Icons.backspace_outlined,
                        size: 13,
                        color: muted,
                      ),
                      label: const Text(
                        'សម្អាត',
                        style: TextStyle(fontSize: 11, color: muted),
                      ),
                      side: const BorderSide(color: line),
                      onPressed: () {
                        _amount.clear();
                        _form.currentState?.validate();
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    const Text(
                      'ប្រភេទចំណាយ',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const Spacer(),
                    InkWell(
                      key: const Key('manageCategoriesButton'),
                      borderRadius: BorderRadius.circular(8),
                      onTap: _manageCategories,
                      child: const Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.swap_vert_rounded,
                              size: 16,
                              color: green,
                            ),
                            SizedBox(width: 4),
                            Text(
                              'រៀបចំ ឬ បន្ថែម',
                              style: TextStyle(
                                fontSize: 12,
                                color: green,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final buttonWidth = (constraints.maxWidth - 16) / 3;
                    final top5 = _categories.take(5).toList();
                    final isCategoryInTop5 = top5.contains(_category);
                    final moreButtonLabel =
                        !isCategoryInTop5 ? _category.label : 'ច្រើនទៀត';
                    final isMoreSelected = !isCategoryInTop5;
                    final moreCategory = !isCategoryInTop5 ? _category : null;

                    return Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final c in top5)
                          SizedBox(
                            width: buttonWidth,
                            child: Semantics(
                              selected: c == _category,
                              child: Material(
                                color: c == _category
                                    ? c.background
                                    : Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  side: BorderSide(
                                    color: c == _category ? c.color : line,
                                    width: c == _category ? 1.5 : 1,
                                  ),
                                ),
                                child: InkWell(
                                  key: Key('category_${c.name}'),
                                  borderRadius: BorderRadius.circular(14),
                                  onTap: () => setState(() => _category = c),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 13,
                                      horizontal: 4,
                                    ),
                                    child: Center(
                                      child: Text(
                                        c.label,
                                        textAlign: TextAlign.center,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: c == _category
                                              ? FontWeight.w700
                                              : FontWeight.w500,
                                          color: c == _category
                                              ? c.color
                                              : ink,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        SizedBox(
                          width: buttonWidth,
                          child: Semantics(
                            selected: isMoreSelected,
                            child: Material(
                              color: isMoreSelected
                                  ? (moreCategory?.background ??
                                      const Color(0xFFF0F2EB))
                                  : Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                                side: BorderSide(
                                  color: isMoreSelected
                                      ? (moreCategory?.color ?? green)
                                      : line,
                                  width: isMoreSelected ? 1.5 : 1,
                                ),
                              ),
                              child: InkWell(
                                key: const Key('category_more'),
                                borderRadius: BorderRadius.circular(14),
                                onTap: _showCategoryPickerSheet,
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 13,
                                    horizontal: 4,
                                  ),
                                  child: Center(
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Flexible(
                                          child: Text(
                                            moreButtonLabel,
                                            textAlign: TextAlign.center,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              fontSize: 12,
                                              fontWeight: isMoreSelected
                                                  ? FontWeight.w700
                                                  : FontWeight.w500,
                                              color: isMoreSelected
                                                  ? (moreCategory?.color ??
                                                      green)
                                                  : muted,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 2),
                                        Icon(
                                          Icons.expand_more_rounded,
                                          size: 14,
                                          color: isMoreSelected
                                              ? (moreCategory?.color ?? green)
                                              : muted,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      flex: 6,
                      child: Material(
                        color: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                          side: const BorderSide(color: line),
                        ),
                        child: InkWell(
                          key: const Key('datePickerButton'),
                          borderRadius: BorderRadius.circular(16),
                          onTap: _pickDate,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 16,
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.calendar_today_outlined,
                                  size: 18,
                                  color: green,
                                ),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    displayDate(_date),
                                    style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const Icon(
                                  Icons.expand_more,
                                  size: 18,
                                  color: muted,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 5,
                      child: Material(
                        color: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                          side: const BorderSide(color: line),
                        ),
                        child: InkWell(
                          key: const Key('timePickerButton'),
                          borderRadius: BorderRadius.circular(16),
                          onTap: _pickTime,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 16,
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.access_time_rounded,
                                  size: 18,
                                  color: green,
                                ),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    formatTime(_date),
                                    style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const Icon(
                                  Icons.expand_more,
                                  size: 18,
                                  color: muted,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Text(
                      _error!,
                      style: const TextStyle(color: Colors.red),
                    ),
                  ),
                const SizedBox(height: 22),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    key: const Key('saveExpense'),
                    onPressed: _saving ? null : _save,
                    icon: _saving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.check_rounded),
                    label: Text(_saving ? 'កំពុងរក្សាទុក...' : 'រក្សាទុកចំណាយ'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
