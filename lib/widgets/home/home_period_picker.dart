import 'package:flutter/material.dart';

import 'package:kot_luy/models/expense.dart';

class HomePeriodPicker extends StatelessWidget {
  const HomePeriodPicker({
    super.key,
    required this.period,
    required this.onSelect,
  });

  final ExpensePeriod period;
  final ValueChanged<ExpensePeriod> onSelect;

  @override
  Widget build(BuildContext context) => Container(
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
                        ExpensePeriod.values.indexOf(period) /
                        (ExpensePeriod.values.length - 1)),
                0,
              ),
              child: FractionallySizedBox(
                widthFactor: 1 / ExpensePeriod.values.length,
                heightFactor: 1,
                child: const DecoratedBox(
                  key: Key('periodPickerThumb'),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.all(Radius.circular(24)),
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
                    selected: p == period,
                    child: Material(
                      color: Colors.transparent,
                      borderRadius: BorderRadius.circular(24),
                      child: InkWell(
                        key: Key('period_${p.name}'),
                        borderRadius: BorderRadius.circular(24),
                        overlayColor: const WidgetStatePropertyAll(
                          Colors.transparent,
                        ),
                        onTap: p == period ? null : () => onSelect(p),
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
}
