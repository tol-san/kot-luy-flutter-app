import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:kot_luy/models/expense.dart';
import 'package:kot_luy/theme.dart';

/// A self-contained input row for adding a new category.
///
/// Features:
/// - Suggests matching existing categories as the user types.
/// - When the name already exists, the button changes label to "មានរួចហើយ" and is disabled.
/// - Clear button (✕) to quickly wipe input.
class CategoryInputRow extends StatefulWidget {
  const CategoryInputRow({
    super.key,
    required this.onAdd,
    this.existingCategories = const [],
    this.onSelectExisting,
    this.isAdding = false,
  });

  /// Called with the trimmed name when the user taps "បន្ថែម" or submits.
  final ValueChanged<String> onAdd;

  /// The list of existing categories to check against and offer suggestions from.
  final List<ExpenseCategory> existingCategories;

  /// Optional callback when the user taps on a suggestion chip.
  final ValueChanged<ExpenseCategory>? onSelectExisting;

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
    _controller.addListener(_onTextChanged);
  }

  void _onFocusChange() {
    if (mounted) setState(() => _isFocused = _focus.hasFocus);
  }

  void _onTextChanged() {
    if (mounted) setState(() {});
  }

  ExpenseCategory? _findExisting(String name) {
    final clean = name.trim().toLowerCase();
    if (clean.isEmpty) return null;
    for (final c in widget.existingCategories) {
      if (c.label.trim().toLowerCase() == clean) return c;
    }
    return null;
  }

  List<ExpenseCategory> _getSuggestions(String query) {
    final clean = query.trim().toLowerCase();
    if (clean.isEmpty) return const [];
    return widget.existingCategories.where((c) {
      return c.label.trim().toLowerCase().contains(clean);
    }).toList();
  }

  void _submit() {
    final text = _controller.text.trim();
    if (widget.isAdding ||
        text.isEmpty ||
        ExpenseCategory.containsEmoji(text)) {
      return;
    }
    final matching = _findExisting(text);
    if (matching != null) {
      widget.onSelectExisting?.call(matching);
      return;
    }
    _controller.clear();
    widget.onAdd(text);
  }

  void _selectSuggestion(ExpenseCategory category) {
    _controller.text = category.label;
    _controller.selection = TextSelection.collapsed(
      offset: category.label.length,
    );
    setState(() {});
    widget.onSelectExisting?.call(category);
  }

  @override
  void dispose() {
    _focus.removeListener(_onFocusChange);
    _controller.removeListener(_onTextChanged);
    _focus.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final text = _controller.text.trim();
    final isDuplicate = _findExisting(text) != null;
    final hasEmoji = ExpenseCategory.containsEmoji(text);
    final suggestions = _getSuggestions(text);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
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
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            key: const Key('addCategoryInput'),
                            controller: _controller,
                            focusNode: _focus,
                            inputFormatters: [
                              LengthLimitingTextInputFormatter(
                                ExpenseCategory.maxLabelLength,
                              ),
                            ],
                            textInputAction: TextInputAction.done,
                            onSubmitted: (_) => _submit(),
                            style: const TextStyle(fontSize: 13, color: ink),
                            decoration: const InputDecoration(
                              hintText: 'បញ្ចូលឈ្មោះមុខចំណាយថ្មី...',
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
                        if (_controller.text.isNotEmpty)
                          GestureDetector(
                            key: const Key('clearCategoryInput'),
                            onTap: () {
                              _controller.clear();
                              setState(() {});
                            },
                            child: const Padding(
                              padding: EdgeInsets.only(left: 6),
                              child: Icon(
                                Icons.cancel_rounded,
                                size: 16,
                                color: muted,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  height: 44,
                  child: FilledButton(
                    key: const Key('addCategoryButton'),
                    onPressed: (widget.isAdding || isDuplicate || hasEmoji)
                        ? null
                        : _submit,
                    style: FilledButton.styleFrom(
                      backgroundColor: green,
                      disabledBackgroundColor: const Color(0xFFE8E5DF),
                      disabledForegroundColor: muted,
                      elevation: 0,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      minimumSize: Size.zero,
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: widget.isAdding
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : (isDuplicate
                              ? const Text(
                                  'មានរួចហើយ',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                )
                              : const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.add_rounded, size: 16),
                                    SizedBox(width: 4),
                                    Text(
                                      'បន្ថែម',
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                )),
                  ),
                ),
              ],
            ),
          ),
          if (hasEmoji) ...[
            const SizedBox(height: 6),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 2),
              child: Text(
                ExpenseCategory.emojiNotAllowedMessage,
                key: Key('categoryEmojiError'),
                style: TextStyle(
                  fontSize: 11,
                  color: Color(0xFFAD5347),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
          if (suggestions.isNotEmpty) ...[
            const SizedBox(height: 8),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 2),
              child: Text(
                'មុខចំណាយដែលមានស្រាប់:',
                style: TextStyle(
                  fontSize: 11,
                  color: muted,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            const SizedBox(height: 6),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: suggestions.map((cat) {
                  return Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        key: Key('categorySuggestion_${cat.name}'),
                        borderRadius: BorderRadius.circular(10),
                        onTap: () => _selectSuggestion(cat),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: line),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 8,
                                height: 8,
                                decoration: BoxDecoration(
                                  color: cat.color,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                cat.label,
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                  color: ink,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
