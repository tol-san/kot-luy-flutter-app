import 'dart:async';

import 'package:clock/clock.dart';
import 'package:flutter/material.dart';

import 'package:kot_luy/data/expense_repository.dart';
import 'package:kot_luy/models/expense.dart';
import 'package:kot_luy/screens/category_management_sheet.dart';
import 'package:kot_luy/theme.dart';
import 'package:kot_luy/widgets/category_picker_sheet.dart';
import 'package:kot_luy/widgets/expense_form/amount_field.dart';
import 'package:kot_luy/widgets/expense_form/category_selector.dart';
import 'package:kot_luy/widgets/expense_form/date_time_picker_row.dart';
import 'package:kot_luy/widgets/riel_input_formatter.dart';

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
  late final _note = TextEditingController(text: widget.expense?.note ?? '');
  late bool _showNote = widget.expense?.note.isNotEmpty ?? false;
  late ExpenseCategory _category =
      widget.expense?.category ?? ExpenseCategory.breakfast;
  List<ExpenseCategory> _categories = ExpenseCategory.values;
  late DateTime _date = widget.expense?.date ?? clock.now();
  late bool _isCustomDateTime = widget.expense != null;
  Timer? _ticker;
  bool _saving = false;
  String? _error;
  String? _dateTimeError;

  void _warnFutureDateTime() {
    setState(() {
      _dateTimeError = 'សូមជ្រើសរើសថ្ងៃ និងម៉ោងបច្ចុប្បន្ន ឬកន្លងមក។';
    });
  }

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
        } else if (!_categories.any((c) => c == _category) &&
            _category.name != widget.expense?.category.name) {
          _category = _categories.first;
        }
      });
    }
  }

  Future<void> _manageCategories() async {
    final result = await CategoryManagementSheet.show(
      context,
      widget.repository,
    );
    if (!mounted) return;
    if (result != null) {
      setState(() {
        _categories = result.categories;
        if (result.selectedCategory != null) {
          _category = result.selectedCategory!;
        } else if (!_categories.any((c) => c == _category) &&
            _category.name != widget.expense?.category.name) {
          _category = _categories.first;
        }
      });
    } else {
      await _loadCategories();
    }
  }

  Future<void> _showCategoryPickerSheet() async {
    final selected = await CategoryPickerSheet.show(
      context,
      categories: _categories,
      selectedCategory: _category,
      onManageCategories: _manageCategories,
    );
    if (selected != null && mounted) {
      setState(() => _category = selected);
    }
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _amount.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving || !_form.currentState!.validate()) return;
    final now = clock.now();
    final dateToSave = _isCustomDateTime ? _date : now;
    if (dateToSave.isAfter(now)) {
      _warnFutureDateTime();
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.repository.save(
        Expense(
          id: widget.expense?.id,
          amount: parseRielInput(_amount.text),
          category: _category,
          date: dateToSave,
          note: _note.text.trim(),
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
      final newDate = DateTime(
        picked.year,
        picked.month,
        picked.day,
        _date.hour,
        _date.minute,
      );
      if (newDate.isAfter(clock.now())) {
        _warnFutureDateTime();
        return;
      }
      _ticker?.cancel();
      setState(() {
        _isCustomDateTime = true;
        _date = newDate;
        _dateTimeError = null;
      });
    }
  }

  Future<void> _pickTime() async {
    final pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: _date.hour, minute: _date.minute),
    );
    if (pickedTime != null && mounted) {
      final now = clock.now();
      final candidate = DateTime(
        _date.year,
        _date.month,
        _date.day,
        pickedTime.hour,
        pickedTime.minute,
      );
      if (candidate.isAfter(now)) {
        _warnFutureDateTime();
      } else {
        _ticker?.cancel();
        setState(() {
          _isCustomDateTime = true;
          _date = candidate;
          _dateTimeError = null;
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
                AmountField(controller: _amount, formKey: _form),
                const SizedBox(height: 18),
                CategorySelector(
                  categories: _categories,
                  selected: _category,
                  onSelect: (c) => setState(() => _category = c),
                  onMore: _showCategoryPickerSheet,
                  onManage: _manageCategories,
                ),
                const SizedBox(height: 20),
                DateTimePickerRow(
                  date: _date,
                  onPickDate: _pickDate,
                  onPickTime: _pickTime,
                  errorText: _dateTimeError,
                ),
                const SizedBox(height: 14),
                Align(
                  alignment: Alignment.centerLeft,
                  child: InkWell(
                    key: const Key('toggleNoteOption'),
                    borderRadius: BorderRadius.circular(10),
                    onTap: () => setState(() => _showNote = !_showNote),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        vertical: 4,
                        horizontal: 2,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            _showNote
                                ? Icons.remove_circle_outline_rounded
                                : Icons.add_circle_outline_rounded,
                            size: 16,
                            color: green,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            _showNote ? 'លាក់កំណត់ចំណាំ' : '+ បន្ថែមកំណត់ចំណាំ',
                            style: const TextStyle(
                              fontSize: 12,
                              color: green,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                if (_showNote) ...[
                  const SizedBox(height: 8),
                  TextFormField(
                    key: const Key('noteInput'),
                    controller: _note,
                    maxLines: 1,
                    maxLength: Expense.maxNoteLength,
                    textInputAction: TextInputAction.done,
                    style: const TextStyle(fontSize: 14),
                    decoration: InputDecoration(
                      hintText: 'សរសេរកំណត់ចំណាំ...',
                      hintStyle:
                          const TextStyle(fontSize: 13, color: muted),
                      counterText: '',
                      filled: true,
                      fillColor: Colors.white,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
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
                        borderSide:
                            const BorderSide(color: green, width: 1.5),
                      ),
                    ),
                  ),
                ],
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
                    label: Text(
                      _saving ? 'កំពុងរក្សាទុក...' : 'រក្សាទុកចំណាយ',
                    ),
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
