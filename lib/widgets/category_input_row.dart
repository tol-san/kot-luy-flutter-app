import 'package:flutter/material.dart';

import '../theme.dart';

/// A self-contained input row for adding a new category.
///
/// Owns its own [TextEditingController] and [FocusNode] so the parent sheet
/// does not need to manage them directly.
class CategoryInputRow extends StatefulWidget {
  const CategoryInputRow({
    super.key,
    required this.onAdd,
    this.isAdding = false,
  });

  /// Called with the trimmed name when the user taps "បន្ថែម" or submits.
  final ValueChanged<String> onAdd;

  /// When true the button shows a spinner and is disabled.
  final bool isAdding;

  @override
  State<CategoryInputRow> createState() => _CategoryInputRowState();
}

class _CategoryInputRowState extends State<CategoryInputRow> {
  final _controller = TextEditingController();
  final _focus = FocusNode();
  bool _isFocused = false;

  @override
  void initState() {
    super.initState();
    _focus.addListener(_onFocusChange);
  }

  void _onFocusChange() {
    if (mounted) setState(() => _isFocused = _focus.hasFocus);
  }

  void _submit() {
    final text = _controller.text.trim();
    if (text.isEmpty || widget.isAdding) return;
    _controller.clear();
    widget.onAdd(text);
  }

  @override
  void dispose() {
    _focus.removeListener(_onFocusChange);
    _focus.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
      child: SizedBox(
        height: 44,
        child: Row(
          children: [
            Expanded(
              child: Container(
                height: 44,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: _isFocused ? green : line,
                    width: _isFocused ? 1.5 : 1,
                  ),
                ),
                alignment: Alignment.center,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: TextField(
                  key: const Key('addCategoryInput'),
                  controller: _controller,
                  focusNode: _focus,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _submit(),
                  style: const TextStyle(fontSize: 13, color: ink),
                  decoration: const InputDecoration(
                    hintText: 'បញ្ចូលឈ្មោះប្រភេទថ្មី...',
                    hintStyle: TextStyle(fontSize: 13, color: muted),
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    errorBorder: InputBorder.none,
                    disabledBorder: InputBorder.none,
                    filled: false,
                    isDense: true,
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              height: 44,
              child: FilledButton.icon(
                key: const Key('addCategoryButton'),
                onPressed: widget.isAdding ? null : _submit,
                style: FilledButton.styleFrom(
                  backgroundColor: green,
                  elevation: 0,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  minimumSize: Size.zero,
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                icon: widget.isAdding
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.add_rounded, size: 16),
                label: const Text(
                  'បន្ថែម',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
