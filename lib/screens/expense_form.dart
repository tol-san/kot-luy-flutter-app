import 'dart:async';

import 'package:clock/clock.dart';
import 'package:flutter/material.dart';

import '../data/expense_repository.dart';
import '../models/expense.dart';
import '../theme.dart';
import '../widgets/riel_input_formatter.dart';

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
  late final _otherTitle = TextEditingController(
    text: widget.expense?.category == ExpenseCategory.other
        ? (widget.expense?.title ?? '')
        : '',
  );
  late ExpenseCategory _category =
      widget.expense?.category ?? ExpenseCategory.breakfast;
  late DateTime _date = widget.expense?.date ?? clock.now();
  late bool _isCustomDateTime = widget.expense != null;
  Timer? _ticker;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
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

  @override
  void dispose() {
    _ticker?.cancel();
    _amount.dispose();
    _otherTitle.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving || !_form.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final title = _category == ExpenseCategory.other
          ? (_otherTitle.text.trim().isEmpty ? 'ផ្សេងៗ' : _otherTitle.text.trim())
          : _category.label;
      final dateToSave = _isCustomDateTime ? _date : clock.now();
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
                const Text(
                  'ប្រភេទចំណាយ',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 10),
                LayoutBuilder(
                  builder: (context, constraints) => Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: ExpenseCategory.values
                        .map(
                          (c) => SizedBox(
                            width: (constraints.maxWidth - 16) / 3,
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
                        )
                        .toList(),
                  ),
                ),
                if (_category == ExpenseCategory.other) ...[
                  const SizedBox(height: 14),
                  TextFormField(
                    key: const Key('customTitleInput'),
                    controller: _otherTitle,
                    autofocus: true,
                    maxLength: 80,
                    decoration: const InputDecoration(
                      labelText: 'ឈ្មោះចំណាយផ្សេងៗ',
                      hintText: 'ឧ. ទិញសៀវភៅ, កាត់សក់...',
                      counterText: '',
                    ),
                  ),
                ],
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: Material(
                        color: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                          side: const BorderSide(color: line),
                        ),
                        child: InkWell(
                          key: const Key('datePickerButton'),
                          borderRadius: BorderRadius.circular(16),
                          onTap: () async {
                            final now = clock.now();
                            final effectiveLastDate =
                                now.isAfter(_date) ? now : _date;
                            final picked = await showDatePicker(
                              context: context,
                              initialDate: _date,
                              firstDate: DateTime(2000),
                              lastDate: effectiveLastDate.add(
                                const Duration(days: 365),
                              ),
                            );
                            if (picked != null && mounted) {
                              _ticker?.cancel();
                              setState(() {
                                _isCustomDateTime = true;
                                _date = DateTime(
                                  picked.year,
                                  picked.month,
                                  picked.day,
                                  _date.hour,
                                  _date.minute,
                                );
                              });
                            }
                          },
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 16,
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.calendar_today_outlined,
                                  size: 18,
                                  color: green,
                                ),
                                const SizedBox(width: 8),
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
                    const SizedBox(width: 10),
                    Expanded(
                      flex: 2,
                      child: Material(
                        color: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                          side: const BorderSide(color: line),
                        ),
                        child: InkWell(
                          key: const Key('timePickerButton'),
                          borderRadius: BorderRadius.circular(16),
                          onTap: () async {
                            final pickedTime = await showTimePicker(
                              context: context,
                              initialTime: TimeOfDay(
                                hour: _date.hour,
                                minute: _date.minute,
                              ),
                            );
                            if (pickedTime != null && mounted) {
                              _ticker?.cancel();
                              setState(() {
                                _isCustomDateTime = true;
                                _date = DateTime(
                                  _date.year,
                                  _date.month,
                                  _date.day,
                                  pickedTime.hour,
                                  pickedTime.minute,
                                );
                              });
                            }
                          },
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 16,
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.access_time_rounded,
                                  size: 18,
                                  color: green,
                                ),
                                const SizedBox(width: 8),
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
