import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../data/expense_repository.dart';
import '../models/expense.dart';
import '../theme.dart';
import 'expense_form.dart';

class DetailScreen extends StatefulWidget {
  const DetailScreen({
    super.key,
    required this.expense,
    required this.repository,
  });
  final Expense expense;
  final ExpenseRepository repository;
  @override
  State<DetailScreen> createState() => _DetailScreenState();
}

class _DetailScreenState extends State<DetailScreen> {
  late Expense _expense = widget.expense;
  bool _deleting = false;
  Future<void> _edit() async {
    final saved = await showExpenseForm(
      context,
      widget.repository,
      expense: _expense,
    );
    if (saved != true || !mounted) return;
    try {
      final all = await widget.repository.all();
      if (mounted) {
        setState(() => _expense = all.firstWhere((e) => e.id == _expense.id));
      }
    } catch (_) {
      if (mounted) Navigator.pop(context);
    }
  }

  Future<void> _delete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('លុបចំណាយនេះ?'),
        content: Text('«${_expense.title}» នឹងត្រូវបានលុបចេញពីបញ្ជីរបស់អ្នក។'),
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
    if (confirmed != true || !mounted) return;
    setState(() => _deleting = true);
    try {
      await widget.repository.delete(_expense.id!);
      if (mounted) Navigator.pop(context);
    } catch (_) {
      if (mounted) {
        setState(() => _deleting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('លុបមិនបាន សូមព្យាយាមម្ដងទៀត')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('ចំណាយលម្អិត', style: TextStyle(fontSize: 18)),
    ),
    body: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 600),
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            const SizedBox(height: 16),
            Text(
              _expense.title,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 10),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                riel(_expense.amount),
                style: const TextStyle(
                  fontSize: 42,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -1.5,
                ),
              ),
            ),
            const SizedBox(height: 28),
            Container(
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(color: line),
                borderRadius: BorderRadius.circular(24),
              ),
              child: Column(
                children: [
                  _row(
                    Icons.grid_view_rounded,
                    'មុខចំណាយ',
                    _expense.category.label,
                  ),
                  const Divider(height: 32),
                  _row(
                    Icons.calendar_today_outlined,
                    'កាលបរិច្ឆេទ',
                    '${displayDate(_expense.date)} • ${formatTime(_expense.date)}',
                  ),
                  const Divider(height: 32),
                  _row(Icons.payments_outlined, 'រូបិយប័ណ្ណ', 'រៀល (KHR)'),
                  if (_expense.note.isNotEmpty) ...[
                    const Divider(height: 32),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'កំណត់ចំណាំ',
                            style: TextStyle(fontSize: 12, color: muted),
                          ),
                          const SizedBox(height: 8),
                          Text(_expense.note),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 22),
            Row(
              children: [
                SvgPicture.asset(
                  'assets/illustrations/wallet.svg',
                  width: 76,
                  height: 76,
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'ការកត់ត្រាតូចមួយ\nជាជំហានល្អសម្រាប់ខ្លួនឯង។',
                    style: TextStyle(color: muted, fontSize: 12),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _deleting ? null : _edit,
              icon: const Icon(Icons.edit_outlined, size: 19),
              label: const Text('កែប្រែចំណាយ'),
            ),
            const SizedBox(height: 10),
            TextButton.icon(
              onPressed: _deleting ? null : _delete,
              icon: const Icon(Icons.delete_outline, size: 19),
              label: Text(_deleting ? 'កំពុងលុប...' : 'លុបចំណាយ'),
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFFAD5347),
                minimumSize: const Size(0, 50),
              ),
            ),
          ],
        ),
      ),
    ),
  );
  Widget _row(IconData icon, String label, String value) => Row(
    children: [
      Icon(icon, size: 19, color: muted),
      const SizedBox(width: 10),
      Text(label, style: const TextStyle(color: muted, fontSize: 12)),
      const SizedBox(width: 16),
      Expanded(
        child: Text(
          value,
          textAlign: TextAlign.right,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
        ),
      ),
    ],
  );
}
