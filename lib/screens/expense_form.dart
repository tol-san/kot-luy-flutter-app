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
  late final _title = TextEditingController(text: widget.expense?.title ?? '');
  late final _amount = TextEditingController(
    text: formatRielInput(widget.expense?.amount.toString() ?? ''),
  );
  late final _note = TextEditingController(text: widget.expense?.note ?? '');
  late ExpenseCategory _category =
      widget.expense?.category ?? ExpenseCategory.food;
  late DateTime _date = widget.expense?.date ?? clock.now();
  bool _saving = false;
  String? _error;
  @override
  void dispose() {
    _title.dispose();
    _amount.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving || !_form.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.repository.save(
        Expense(
          id: widget.expense?.id,
          title: _title.text.trim(),
          amount: int.parse(_amount.text.replaceAll(',', '')),
          category: _category,
          date: _date,
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
                      (int.tryParse((value ?? '').replaceAll(',', '')) ?? 0) <=
                          0
                      ? 'សូមបញ្ចូលចំនួនប្រាក់លើសពី 0'
                      : null,
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [5000, 10000, 20000, 50000, 100000]
                      .map(
                        (v) => ActionChip(
                          label: Text(
                            riel(v),
                            style: const TextStyle(fontSize: 11),
                          ),
                          side: const BorderSide(color: line),
                          onPressed: () {
                            final text = formatRielInput('$v');
                            _amount.value = TextEditingValue(
                              text: text,
                              selection: TextSelection.collapsed(
                                offset: text.length,
                              ),
                            );
                          },
                        ),
                      )
                      .toList(),
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
                                  borderRadius: BorderRadius.circular(14),
                                  onTap: () => setState(() => _category = c),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 11,
                                    ),
                                    child: Column(
                                      children: [
                                        Icon(c.icon, color: c.color, size: 23),
                                        const SizedBox(height: 5),
                                        Text(
                                          c.label,
                                          style: const TextStyle(
                                            fontSize: 11,
                                            color: ink,
                                          ),
                                        ),
                                      ],
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
                const SizedBox(height: 20),
                TextFormField(
                  key: const Key('titleInput'),
                  controller: _title,
                  maxLength: 80,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: 'ចំណាយលើអ្វី?',
                    hintText: 'ឧ. បាយថ្ងៃត្រង់',
                    counterText: '',
                  ),
                  validator: (value) => value == null || value.trim().isEmpty
                      ? 'សូមបញ្ចូលឈ្មោះចំណាយ'
                      : null,
                ),
                const SizedBox(height: 14),
                Material(
                  color: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: const BorderSide(color: line),
                  ),
                  child: ListTile(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    leading: const Icon(
                      Icons.calendar_today_outlined,
                      size: 20,
                      color: green,
                    ),
                    title: Text(
                      displayDate(_date),
                      style: const TextStyle(fontSize: 13),
                    ),
                    trailing: const Icon(Icons.expand_more),
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: _date,
                        firstDate: DateTime(2000),
                        lastDate: clock.now(),
                      );
                      if (picked != null && mounted) {
                        setState(
                          () => _date = DateTime(
                            picked.year,
                            picked.month,
                            picked.day,
                            _date.hour,
                            _date.minute,
                          ),
                        );
                      }
                    },
                  ),
                ),
                const SizedBox(height: 14),
                TextFormField(
                  key: const Key('noteInput'),
                  controller: _note,
                  maxLines: 2,
                  maxLength: 500,
                  decoration: const InputDecoration(
                    labelText: 'កំណត់ចំណាំ (មិនចាំបាច់)',
                    counterText: '',
                    alignLabelWithHint: true,
                  ),
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
