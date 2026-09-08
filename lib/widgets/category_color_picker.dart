import 'package:flutter/material.dart';

import 'package:kot_luy/theme.dart';

class CategoryColorPicker extends StatelessWidget {
  const CategoryColorPicker({
    super.key,
    required this.colors,
    required this.selectedColor,
    required this.onChanged,
  });

  final List<Color> colors;
  final Color selectedColor;
  final ValueChanged<Color> onChanged;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
    child: Row(
      children: [
        const Text(
          'ពណ៌',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: ink,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: colors
                .map(
                  (color) => Semantics(
                    selected: color == selectedColor,
                    button: true,
                    child: InkWell(
                      key: Key('categoryColor_${color.toARGB32()}'),
                      onTap: () => onChanged(color),
                      borderRadius: BorderRadius.circular(18),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          color: color,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: color == selectedColor ? ink : Colors.white,
                            width: color == selectedColor ? 2.5 : 1,
                          ),
                        ),
                        child: color == selectedColor
                            ? const Icon(
                                Icons.check_rounded,
                                color: Colors.white,
                                size: 16,
                              )
                            : null,
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
        ),
      ],
    ),
  );
}
