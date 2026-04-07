//  week_multi_select.dart
import 'package:flutter/material.dart';
import 'package:kleenops_admin/widgets/buttons/button_select_text.dart';

/// Multi-select for week ordinals (1st-5th) using `ButtonSelectText`.
class WeekMultiSelectDropdown extends StatelessWidget {
  final List<String> selectedWeeks;
  final ValueChanged<List<String>> onChanged;
  final List<String> options;

  const WeekMultiSelectDropdown({
    super.key,
    required this.selectedWeeks,
    required this.onChanged,
    this.options = const ['1st', '2nd', '3rd', '4th', '5th'],
  });

  @override
  Widget build(BuildContext context) {
    return InputDecorator(
      decoration: const InputDecoration(
        labelText: 'Weeks',
        border: OutlineInputBorder(),
      ),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: options.map((wk) {
          final isSelected = selectedWeeks.contains(wk);
          return ButtonSelectText(
            label: wk,
            selected: isSelected,
            onTap: () {
              final newSel = List<String>.from(selectedWeeks);
              if (isSelected) {
                newSel.remove(wk);
              } else {
                newSel.add(wk);
              }
              onChanged(newSel);
            },
          );
        }).toList(),
      ),
    );
  }
}
