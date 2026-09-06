import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/expense.dart';
import '../theme.dart';

class ExpenseChart extends StatelessWidget {
  const ExpenseChart({super.key, required this.expenses, this.size = 124});
  final List<Expense> expenses;
  final double size;
  @override
  Widget build(BuildContext context) {
    final totals = <ExpenseCategory, int>{};
    for (final e in expenses) {
      totals.update(e.category, (v) => v + e.amount, ifAbsent: () => e.amount);
    }
    return Semantics(
      label:
          'ក្រាហ្វចំណាយ ${totals.entries.map((e) => '${e.key.label} ${riel(e.value)}').join(', ')}',
      child: SizedBox(
        width: size,
        height: size,
        child: CustomPaint(
          painter: _DonutPainter(totals),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${totals.length}',
                  style: const TextStyle(
                    fontSize: 25,
                    fontWeight: FontWeight.w700,
                    color: ink,
                    height: 1.3,
                  ),
                ),
                const Text(
                  'ប្រភេទ',
                  style: TextStyle(fontSize: 10, color: muted),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DonutPainter extends CustomPainter {
  _DonutPainter(this.totals);
  final Map<ExpenseCategory, int> totals;
  @override
  void paint(Canvas canvas, Size size) {
    final rect = (Offset.zero & size).deflate(9);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 13
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(rect, 0, math.pi * 2, false, paint..color = line);
    final sum = totals.values.fold(0, (a, b) => a + b);
    if (sum == 0) return;
    var start = -math.pi / 2;
    for (final category in ExpenseCategory.values) {
      final value = totals[category] ?? 0;
      if (value == 0) continue;
      final sweep = value / sum * math.pi * 2;
      final gap = totals.length > 1 ? math.min(.11, sweep * .2) : 0.0;
      canvas.drawArc(
        rect,
        start + gap / 2,
        sweep - gap,
        false,
        paint..color = category.color,
      );
      start += sweep;
    }
  }

  @override
  bool shouldRepaint(covariant _DonutPainter oldDelegate) => true;
}
