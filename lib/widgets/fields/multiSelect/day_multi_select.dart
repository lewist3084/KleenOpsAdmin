//  day_multi_select.dart
import 'package:flutter/material.dart';
import 'package:kleenops_admin/widgets/buttons/button_select_text.dart';

/// A reusable multi-select field for days of the week using `ButtonSelectText`.
class DayMultiSelectDropdown extends StatelessWidget {
  final List<String> selectedDays;
  final ValueChanged<List<String>> onChanged;

  /// You can pass a custom list if you ever need a different ordering.
  final List<String> options;

  const DayMultiSelectDropdown({
    super.key,
    required this.selectedDays,
    required this.onChanged,
    this.options = const ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'],
  });

  @override
  Widget build(BuildContext context) {
    return InputDecorator(
      decoration: const InputDecoration(
        labelText: 'Days of Week',
        border: OutlineInputBorder(),
      ),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: options.map((day) {
          final isSelected = selectedDays.contains(day);
          return ButtonSelectText(
            label: day,
            selected: isSelected,
            onTap: () {
              final newSel = List<String>.from(selectedDays);
              if (isSelected) {
                newSel.remove(day);
              } else {
                newSel.add(day);
              }
              onChanged(newSel);
            },
          );
        }).toList(),
      ),
    );
  }
}
