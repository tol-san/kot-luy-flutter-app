import 'package:flutter/material.dart';

import 'package:kot_luy/models/expense.dart';
import 'package:kot_luy/theme.dart';
import 'package:kot_luy/widgets/riel_input_formatter.dart';

/// Amount TextFormField + quick-amount chips.
///
/// Parameters are passed as controllers / callbacks so the parent [_ExpenseFormState]
/// retains full control over the form state.
class AmountField extends StatelessWidget {
  const AmountField({
    super.key,
    required this.controller,
    required this.formKey,
  });

  final TextEditingController controller;
  final GlobalKey<FormState> formKey;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'ចំនួនទឹកប្រាក់',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        TextFormField(
          key: const Key('amountInput'),
          controller: controller,
          keyboardType: TextInputType.number,
          inputFormatters: [RielInputFormatter()],
          autovalidateMode: AutovalidateMode.onUserInteraction,
          onChanged: (_) => formKey.currentState?.validate(),
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
              parseRielInput(value) <= 0 ? 'សូមបញ្ចូលចំនួនប្រាក់លើសពី 0' : null,
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            ...[500, 1000, 2000, 3000, 5000, 10000].map(
              (v) => ActionChip(
                key: Key('quick_amount_$v'),
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                visualDensity: VisualDensity.compact,
                label: Text(
                  '+${riel(v)}',
                  style: const TextStyle(fontSize: 11),
                ),
                side: const BorderSide(color: line),
                onPressed: () {
                  final current = parseRielInput(controller.text);
                  final next = current + v;
                  if (next <= 999999999999) {
                    final text = formatRielInput('$next');
                    controller.value = TextEditingValue(
                      text: text,
                      selection: TextSelection.collapsed(offset: text.length),
                    );
                    formKey.currentState?.validate();
                  }
                },
              ),
            ),
            ActionChip(
              key: const Key('clearAmount'),
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              visualDensity: VisualDensity.compact,
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
                controller.clear();
                formKey.currentState?.validate();
              },
            ),
          ],
        ),
      ],
    );
  }
}
