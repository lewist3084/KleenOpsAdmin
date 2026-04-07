//  month_multi_select.dart
import 'package:flutter/material.dart';
import 'package:kleenops_admin/widgets/buttons/button_select_text.dart';

/// Multi‑select for months of the year using `ButtonSelectText` chips.
class MonthMultiSelectDropdown extends StatelessWidget {
  final List<String> selectedMonths;
  final ValueChanged<List<String>> onChanged;
  final List<String> options;

  const MonthMultiSelectDropdown({
    super.key,
    required this.selectedMonths,
    required this.onChanged,
    this.options = const [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December',
    ],
  });

  @override
  Widget build(BuildContext context) {
    return InputDecorator(
      decoration: const InputDecoration(
        labelText: 'Months',
        border: OutlineInputBorder(),
      ),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: options.map((mo) {
          final isSelected = selectedMonths.contains(mo);
          return ButtonSelectText(
            label: mo,
            selected: isSelected,
            onTap: () {
              final newSel = List<String>.from(selectedMonths);
              if (isSelected) {
                newSel.remove(mo);
              } else {
                newSel.add(mo);
              }
              onChanged(newSel);
            },
          );
        }).toList(),
      ),
    );
  }
}
