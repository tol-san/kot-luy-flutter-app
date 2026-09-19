import 'package:flutter/material.dart';

import 'package:kot_luy/models/expense.dart';

/// Preview card showing selected period title, expense count, total, and an optional
/// large-count warning. Extracted from [_PdfExportSheetState._buildPreviewCard].
class PdfPreviewCard extends StatelessWidget {
  const PdfPreviewCard({
    super.key,
    required this.periodTitle,
    required this.count,
    required this.total,
  });

  final String periodTitle;
  final int count;
  final int total;

  static const muted = Color(0xFF5E6B56);
  static const ink = Color(0xFF213426);
  static const line = Color(0xFFD8DFD0);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFFF1F5EB),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: line),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      periodTitle,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: ink,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'រកឃើញចំណាយចំនួន $count ប្រតិបត្តិការ • សរុប ${riel(total)}',
                      style: const TextStyle(fontSize: 11, color: muted),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        if (count > 1000) ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF8E1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFFFE082)),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.info_outline_rounded,
                  size: 16,
                  color: Color(0xFFB78103),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'ចំណាយ $count ប្រតិបត្តិការ — PDF អាចមានទំព័រច្រើន។ ណែនាំជ្រើសរើសរយៈពេលខ្លីជាងនេះដើម្បីងាយស្រួលអាន។',
                    style: const TextStyle(
                      fontSize: 11,
                      color: Color(0xFF795548),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}
