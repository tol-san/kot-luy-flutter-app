import 'package:flutter/material.dart';

/// Dismissible alert banner displaying error messages for backup operations.
class BackupErrorBanner extends StatelessWidget {
  const BackupErrorBanner({
    super.key,
    required this.message,
    required this.onDismiss,
  });

  final String message;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFBF0EF),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFF3D0CB)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 2),
            child: Icon(
              Icons.error_outline_rounded,
              color: Color(0xFFAD5347),
              size: 20,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: Color(0xFFAD5347),
                fontSize: 13,
                height: 1.5,
              ),
            ),
          ),
          const SizedBox(width: 4),
          GestureDetector(
            onTap: onDismiss,
            child: const Padding(
              padding: EdgeInsets.all(2),
              child: Icon(
                Icons.close_rounded,
                color: Color(0xFFAD5347),
                size: 18,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
