import 'package:flutter/material.dart';

import 'package:kot_luy/models/expense.dart';
import 'package:kot_luy/theme.dart';

/// A row containing a date picker button and a time picker button,
/// plus an optional future-date error message beneath them.
class DateTimePickerRow extends StatelessWidget {
  const DateTimePickerRow({
    super.key,
    required this.date,
    required this.onPickDate,
    required this.onPickTime,
    this.errorText,
  });

  final DateTime date;
  final VoidCallback onPickDate;
  final VoidCallback onPickTime;
  final String? errorText;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
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
                  onTap: onPickDate,
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
                            displayDate(date),
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const Icon(Icons.expand_more, size: 18, color: muted),
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
                  onTap: onPickTime,
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
                            formatTime(date),
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const Icon(Icons.expand_more, size: 18, color: muted),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
        if (errorText != null)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Semantics(
              liveRegion: true,
              child: Text(
                errorText!,
                key: const Key('futureDateTimeWarning'),
                style: TextStyle(
                  color: Theme.of(context).colorScheme.error,
                  fontSize: 12,
                ),
              ),
            ),
          ),
      ],
    );
  }
}
