//  multi_select_chips.dart

import 'package:flutter/material.dart';
import 'package:shared_widgets/theme/app_palette.dart';

class MultiSelectChips extends StatelessWidget {
  final String title;
  final List<String> options;
  final List<String> selectedValues;
  final ValueChanged<List<String>> onChanged;

  const MultiSelectChips({
    super.key,
    required this.title,
    required this.options,
    required this.selectedValues,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return FormField<List<String>>(
      initialValue: selectedValues,
      validator: (_) => null,
      builder: (state) {
        return InputDecorator(
          decoration: InputDecoration(
            labelText: title,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(5.0),
            ),
          ),
          child: Wrap(
            spacing: 8.0,
            children: options.map((option) {
              final isSelected = selectedValues.contains(option);
              return ChoiceChip(
                label: Text(option),
                selected: isSelected,
                selectedColor: AppPaletteScope.of(context).primary2,
                backgroundColor: Colors.grey[300],
                labelStyle: TextStyle(
                  color: isSelected ? Colors.black : Colors.black,
                ),
                onSelected: (bool selected) {
                  final newValues = List<String>.from(selectedValues);
                  if (selected && !newValues.contains(option)) {
                    newValues.add(option);
                  } else {
                    newValues.remove(option);
                  }
                  onChanged(newValues);
                },
              );
            }).toList(),
          ),
        );
      },
    );
  }
}
